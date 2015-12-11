#!/bin/bash
#
# Manages Docker containers, images and environments.  Usage formating borrowed
# directly from Docker.  Proceed to Main section for directions.
#
# Halt on errors or uninitialized variables
#
set -e -o nounset


################################################################################
# Functions - must preceed execution
################################################################################


# Output usage help
#
usage_help ()
{
	echo
	echo "This script creates Gateways in Docker containers"
	echo
	echo "Usage: ./endpoint.sh COMMAND [arguments]"
	echo
	echo "Commands:"
	echo "	deploy      Run a Gateway and database"
	echo "	import      Import using OSCAR E2E and Plugins"
	echo "	configure   Configure Docker, MongoDB and bash"
	echo
}


# Pull images and create containers, replacing if necessary
#
docker_run ()
{
	# Expects a name, run options and an image
	NAME=$1
	OPTS=$2
	IMG=$3

	# Pull and remove existing container
	[ $( echo ${IMG} | grep local ) ]|| \
		sudo docker pull ${IMG}
	sudo docker rm -fv ${NAME} || true

	# Notify and run new conatiner
	echo
	echo "*** Running ${NAME} *** sudo docker run -d --name=${NAME} ${OPTS} ${IMG}"
	echo
	sudo docker run -d --name=${NAME} ${OPTS} ${IMG}
	echo
	echo
}


# Run a new gateway
#
docker_deploy ()
{
	# Run database, if necessary
	[ $( sudo docker inspect -f {{.State.Running}} ${NAME_DATABASE} ) ]|| \
		docker_run ${NAME_DATABASE} "${RUN_DATABASE}" ${IMG_DATABASE}

	# Run gateway
	docker_run ${NAME_GATEWAY} "${RUN_GATEWAY}" ${IMG_GATEWAY}

	# Configure SSH, but fails without tty (e.g. cron'd import)
	[ "${COMMAND}" == "import" ]|| \
		sudo docker exec -ti ${NAME_GATEWAY} /app/ssh_config.sh

	# If in test group, then start test gateway(s)
	[ "${TEST_OPT_IN,,}" != "yes" ]|| \
	{
		docker_run ${MASTER_NAME_GATEWAY} "${MASTER_RUN_GATEWAY}" ${MASTER_IMG_GATEWAY}
		docker_run ${DEV_NAME_GATEWAY} "${DEV_RUN_GATEWAY}" ${DEV_IMG_GATEWAY}
		sudo docker exec -ti ${MASTER_NAME_GATEWAY} /app/ssh_config.sh || true
		sudo docker exec -ti ${DEV_NAME_GATEWAY} /app/ssh_config.sh || true
	}
}


# Import an OSCAR SQL dump, containers not persistent
#
docker_import ()
{
	docker_deploy
	docker_run ${NAME_OSCAR} "${RUN_OSCAR}" ${IMG_OSCAR}
}


configure ()
{
	# Configure ~/.bashrc, if necessary
	if(! grep --quiet 'function dockin()' ${HOME}/.bashrc )
	then
		( \
			echo ""; \
			echo "# Function to quickly enter containers"; \
			echo "#"; \
			echo "function c()"; \
			echo "{"; \
			echo "	sudo docker exec -it \$1 /bin/bash"; \
			echo "}"; \
			echo ""; \
			echo "# Function to remove stopped containers and untagged images"; \
			echo "#"; \
			echo "function dclean()"; \
			echo "{"; \
			echo "  sudo docker rm \$( sudo docker ps -a -q )"; \
			echo "  sudo docker rmi \$( sudo docker images | grep '^<none>' | awk '{print \$3}' )"; \
			echo "}"; \
			echo ""; \
			echo "# Aliases to frequently used functions and applications"; \
			echo "#"; \
			echo "alias d='sudo docker'"; \
			echo "alias i='sudo docker inspect'"; \
			echo "alias l='sudo docker logs -f'"; \
			echo "alias p='sudo docker ps -a'"; \
			echo "alias s='sudo docker ps -a | less -S'"; \
			echo "alias dstats='sudo docker stats \$( sudo docker ps -a -q )'"; \
		) | tee -a ${HOME}/.bashrc; \
		echo ""; \
		echo ""; \
		echo "Please log in/out for changes to take effect!"; \
		echo ""; \
	fi

	# Create OSP account
	sudo mkdir -p ${PATH_IMPORT}
	if(! grep --quiet 'OSP Export Account' /etc/passwd )
	then
		sudo useradd -m -d ${PATH_IMPORT} -c "OSP Export Account" -s /bin/bash exporter
	fi

	# Create post-boot script (assumes /encrypted/ is encrypted)
	START=${HOME}/ep-start.sh
  ( \
		echo '#!/bin/bash'; \
		echo '#'; \
		echo 'set -e -o nounset'; \
		echo ''; \
		echo ''; \
		echo '# Decrypt /encrypted/'; \
		echo '#'; \
		echo '[ -s /encrypted/docker/endpoint.env ]|| \'; \
    echo '	sudo /usr/bin/encfs --public /.encrypted /encrypted'; \
		echo ''; \
		echo ''; \
		echo '# Start Docker'; \
		echo '#'; \
		echo '[ $( pgrep -c docker ) -gt 0 ]|| \'; \
    echo '	sudo service docker start'; \
		echo ''; \
		echo ''; \
		echo '# Add static IP, if provided in env file'; \
		echo '#'; \
		echo '. '${SCRIPT_DIR}'/endpoint.env'; \
		echo 'IP_STATIC=${IP_STATIC:-"."}'; \
		echo '[ $( hostname -I )| grep ${IP_STATIC} ]|| \'; \
		echo '	sudo ip addr add ${IP_STATIC} dev em1'; \
	) | tee ${START}; \
	chmod +x ${START}

	# Install Docker, if necessary
	sudo apt-get update
	sudo apt-get install -y linux-image-extra-$(uname -r)
	sudo modprobe aufs
	wget -qO- https://get.docker.com/ | sh

	# Stop Docker from loading at boot
	sudo sed -i '/![^#]/ s/\(^start on.*$\)/#\ \1/' /etc/init/docker.conf

	# Disable Transparent Hugepages for MongoDB, while running
	echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null
	echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null

	# Disable Transparent Hugepage for MongoDB, after reboots
	if(! grep --quiet 'never > /sys/kernel/mm/transparent_hugepage/enabled' /etc/rc.local )
	then
		sudo sed -i '/exit 0/d' /etc/rc.local; \
		( \
			echo ''; \
			echo '# Disable Transparent Hugepage, for Mongo'; \
			echo '#'; \
			echo 'echo never > /sys/kernel/mm/transparent_hugepage/enabled'; \
			echo 'echo never > /sys/kernel/mm/transparent_hugepage/defrag'; \
			echo ''; \
			echo 'exit 0'; \
		) | sudo tee -a /etc/rc.local; \
	fi
	sudo chmod 755 /etc/rc.local
}


################################################################################
# Main - parameters and executions start here!
################################################################################


# Set variables from parameters
#
export COMMAND=${1:-""}


# Get script directory and source endpoint.env
#
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source ${SCRIPT_DIR}/endpoint.env


# If DNS is disabled (,, = lowercase, bash 4+), then use --dns-search=.
#
[ "${DNS_DISABLE,,}" != "yes" ]|| \
	export RUN_GATEWAY="${RUN_GATEWAY} --dns-search=."


# Run based on command
#
case "${COMMAND}" in
	"deploy"      ) docker_deploy;;
	"import"      ) docker_import;;
	"configure"   ) configure;;
	*             ) usage_help;;
esac
