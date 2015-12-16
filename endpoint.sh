#!/bin/bash
#
# Manages Docker containers, images and environments.  Usage formating borrowed
# directly from Docker.  Proceed to Main section for directions.
#
# Halt on errors or uninitialized variables
#
set -e -o nounset


################################################################################
# Functions
################################################################################


# Output usage help
#
usage_help ()
{
	echo
	echo "This script creates Gateways in Docker containers"
	echo
	echo "Usage: ./endpoint.sh COMMAND"
	echo
	echo "Commands:"
	echo "	deploy      Run a Gateway and database"
	echo "	import      Import using OSCAR E2E and Plugins"
	echo "	keygen      Test and create SSH keys"
	echo "	configure   Configure Docker, MongoDB and bash"
	echo
}


# Create SSH keys, if necessary
#
ssh_keygen ()
{
	# Optionally, specify an alternate IP to test against
	SERVER=${1:-${IP_COMPOSER}}

	echo
	if [ ! -s ${PATH_SSH}/id_rsa ]
	then
	  ssh-keygen -b 4096 -t rsa -N "" -C ep${GATEWAY_ID}-$(date +%Y-%m-%d-%T) -f ${PATH_SSH}/id_rsa
		echo "*** SSH keys created in ${PATH_SSH}. ***"
	else
		echo "*** Using SSH keys in ${PATH_SSH}. ***"
	fi
	echo
	cat ${PATH_SSH}/id_rsa.pub
	echo
	echo "Please provide id_rsa.pub (above), a list of participating physicians,"
	echo "their CPSIDs and all paperwork to the PDC at admin@pdcbc.ca."
	echo
	echo "*** Press ENTER to attempt connection to ${SERVER}. ***"
	read -s ENTER_TO_CONTINUE
	ssh -i ${PATH_SSH}/id_rsa -p ${PORT_AUTOSSH} autossh@${SERVER} \
		-o UserKnownHostsFile=${PATH_SSH}/known_hosts /app/test/ssh_landing.sh
}


# Pull images and create containers, replacing if necessary
#
docker_run ()
{
	# Expects a name, run options and an image
	NAME=$1
	OPTS=$2
	IMG=$3

	# Pull image
	[ $( echo ${IMG} | grep local ) ]|| \
		sudo docker pull ${IMG}

	# Remove previous container, if any
	sudo docker rm -fv ${NAME} || true > /dev/null

	# Notify and run new conatiner
	echo
	echo "*** Running ${NAME} *** sudo docker run -d --name=${NAME} ${OPTS} ${IMG}"
	echo
	sudo docker run -d --name=${NAME} ${OPTS} ${IMG}
	echo
}


# Run test group gateways and test connections
#
docker_test ()
{
	docker_run ${MASTER_NAME_GATEWAY} "${MASTER_RUN_GATEWAY}" ${MASTER_IMG_GATEWAY}
	docker_run ${DEV_NAME_GATEWAY} "${DEV_RUN_GATEWAY}" ${DEV_IMG_GATEWAY}
	ssh -i ${PATH_SSH}/id_rsa -p ${PORT_AUTOSSH} autossh@${MASTER_IP_COMPOSER} /app/test/ssh_landing.sh
	ssh -i ${PATH_SSH}/id_rsa -p ${PORT_AUTOSSH} autossh@${DEV_IP_COMPOSER} /app/test/ssh_landing.sh
}


# Run a new gateway
#
docker_deploy ()
{
	# Run/reuse database
	[ $( sudo docker inspect -f {{.State.Running}} ${NAME_DATABASE} ) ]|| \
		docker_run ${NAME_DATABASE} "${RUN_DATABASE}" ${IMG_DATABASE}

	# Run/replace gateway
	docker_run ${NAME_GATEWAY} "${RUN_GATEWAY}" ${IMG_GATEWAY}

	# If in test group, then start test gateway(s)
	[ "${TEST_OPT_IN,,}" != "yes" ]|| \
		docker_test

	# Verify SSH keys, creating if necessary
	ssh_keygen
}


# Import an OSCAR SQL dump, intended to be run on cron schedule
#
docker_import ()
{
	# If using auto update, then update automatically
	[ "${AUTO_UPDATE,,}" != "yes" ]|| \
		docker_deploy

	docker_run ${NAME_OSCAR} "${RUN_OSCAR}" ${IMG_OSCAR}
}


configure_docker ()
{
	# Install Docker
	sudo apt-get update
	sudo apt-get install -y linux-image-extra-$(uname -r)
	sudo modprobe aufs
	wget -qO- https://get.docker.com/ | sh

	# Configure ~/.bashrc, if necessary
	if(! grep --quiet 'function dclean()' ${HOME}/.bashrc )
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
}


configure_mongo ()
{
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


# Configuration specific to PDC managed Endpoints
#
configure_pdc ()
{
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

	# Stop Docker from loading at boot
	sudo sed -i '/![^#]/ s/\(^start on.*$\)/#\ \1/' /etc/init/docker.conf
}


configure_all ()
{
	configure_docker
	configure_mongo
	configure_pdc
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
	"keygen"      ) ssh_keygen;;
	"configure"   ) configure_all;;
	*             ) usage_help;;
esac
