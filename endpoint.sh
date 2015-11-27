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
	echo "	deploy      Run a new Gateway"
	echo "	import      Import using OSCAR E2E and Plugins"
	echo "	configure   Configures Docker, MongoDB and bash"
	echo
	exit
}


# Output message and command, then execute command
#
inform_exec ()
{
	# Expects a message and command
	echo
	echo "*** ${1} *** ${2}"
	echo
	${2} || \
		{
			echo "${2} failed!"
			exit
		}
	echo
	echo
}


# Run a database and set the index (duplicates)
#
docker_database ()
{
	STATUS_DATABASE=$( sudo docker inspect -f {{.State.Running}} ${NAME_DATABASE} ) || true
	if [ ${STATUS_DATABASE} ]
	then
		echo "NOTE: Reusing existing database"
	else
	{
		# Update image and remove container, if stopped
		sudo docker pull mongo
		sudo docker rm ${NAME_DATABASE} || true

		# Run a new container
		inform_exec "Running database" \
			"sudo docker run -d ${RUN_DATABASE}"

		# Set index
		sleep 5
		sudo docker exec ${NAME_DATABASE} /bin/bash -c \
			"mongo query_gateway_development --eval \
  		'printjson( db.records.ensureIndex({ hash_id : 1 }, { unique : true }))'"
	}
	fi

	# Clean up collections
	sudo docker exec ${NAME_DATABASE} mongo query_gateway_development --eval "db.providers.drop()"
	sudo docker exec ${NAME_DATABASE} mongo query_gateway_development --eval "db.queries.drop()"
	sudo docker exec ${NAME_DATABASE} mongo query_gateway_development --eval "db.results.drop()"
}


# Run a new gateway and add populate providers.txt
#
docker_gateway ()
{
	# Update image and remove conatiner
	sudo docker pull ${IMG_GATEWAY}
	sudo docker rm -fv ${NAME_GATEWAY} || true

	# Run a new container
	inform_exec "Running gateway" \
		"sudo docker run -d ${RUN_GATEWAY}"

	# Configure SSH
	inform_exec "Configuring SSH" \
		"sudo docker exec -ti ${NAME_GATEWAY} /app/ssh_config.sh"

	# Populate providers.txt
	inform_exec "Populating providers.txt" \
		"sudo docker exec ${NAME_GATEWAY} /app/providers.sh add ${DOCTOR_IDS}"
}


# Run new test gateways
#
docker_test ()
{
	# Update image and remove containers
	sudo docker pull ${TEST_IMG_GATEWAY}
	sudo docker rm -fv ${TEST_MASTER_NAME_GATEWAY} ${TEST_DEV_NAME_GATEWAY} || true

	# Testing on master branch (not tagged)
	[ -z ${TEST_MASTER_IP_HUB} ]|| \
	{
		# Run a new container
		inform_exec "Running test gateway-master" \
			"sudo docker run -d ${TEST_MASTER_RUN_GATEWAY}"

		# Populate providers.txt
		inform_exec "Populating providers.txt" \
			"sudo docker exec ${TEST_MASTER_NAME_GATEWAY} /app/providers.sh add ${DOCTOR_IDS}"

		# Configure SSH
		inform_exec "Configuring SSH" \
			"sudo docker exec -ti ${TEST_MASTER_NAME_GATEWAY} /app/ssh_config.sh"
	}

	# Testing on dev branch (not tagged)
	[ -z ${TEST_DEV_IP_HUB} ]|| \
	{
		# Run a new container
		inform_exec "Running test gateway-dev" \
			"sudo docker run -d ${TEST_DEV_RUN_GATEWAY}"

		# Populate providers.txt
		inform_exec "Populating providers.txt" \
			"sudo docker exec ${TEST_DEV_NAME_GATEWAY} /app/providers.sh add ${DOCTOR_IDS}"

		# Configure SSH
		inform_exec "Configuring SSH" \
			"sudo docker exec -ti ${TEST_DEV_NAME_GATEWAY} /app/ssh_config.sh"
	}
}


# Run a gateway and database containers, plus test if opted in
#
docker_deploy ()
{
	docker_database
	docker_gateway
	[ "${TEST_OPT_IN,,}" != "yes" ]|| docker_test
}


# Import an OSCAR SQL dump, containers not persistent
#
docker_import ()
{
	# Redeploy Gateway container and ensure database is running
	docker_deploy

	# Update image and remove container, if present
	sudo docker pull ${IMG_OSCAR}
	sudo docker rm -fv ${NAME_OSCAR} || true

	# Run a new foreground container, removed when done (--rm)
	inform_exec "Running OSCAR Exporter" \
		"sudo docker run ${RUN_OSCAR} || true"

	# Have Gateway sync any plugin files back to the Hub
	sudo docker exec ${NAME_GATEWAY} /app/sync_hub.sh
}


docker_configure ()
{
	# Install Docker, if necessary
	( which docker )|| \
		( \
			sudo apt-get update
			sudo apt-get install -y linux-image-extra-$(uname -r); \
			sudo modprobe aufs; \
			wget -qO- https://get.docker.com/ | sh; \
		)

	# Stop Docker from loading at boot
	sudo sed -i '/![^#]/ s/\(^start on.*$\)/#\ \1/' /etc/init/docker.conf


	# Disable Transparent Hugepages for MongoDB, while running
	echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
	echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag

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


	# Create OSP account
	sudo mkdir -p /encrypted/docker/import
	if(! grep --quiet 'OSP Export Account' /etc/passwd ); \
	then
		sudo useradd -m -d /encrypted/docker/import -c "OSP Export Account" -s /bin/bash exporter
	fi


	# Create post-boot script (assumes /encrypted/ is encrypted)
	START=${HOME}/ep-start.sh
	if(! grep --quiet 'sudo service docker start' ${START} ); \
	then \
	  ( \
			echo '#!/bin/bash'; \
			echo '#'; \
			echo 'set -e -o nounset'; \
			echo ''; \
			echo ''; \
			echo '# Decrypt /encrypted/ and source the endpoint.env'; \
			echo '#'; \
			echo '[ -s /encrypted/docker/endpoint.env ]|| \'; \
	    echo '	sudo /usr/bin/encfs --public /.encrypted /encrypted'; \
			echo '. /encrypted/docker/endpoint.env'; \
			echo ''; \
			echo ''; \
			echo '# Start Docker'; \
			echo '#'; \
			echo '[ $(pgrep -c docker) -gt 0 ]|| \'; \
	    echo '	sudo service docker start'; \
			echo ''; \
			echo ''; \
			echo '# Add static IP, if provided in env file'; \
			echo '#'; \
			echo '${IP_STATIC:-""}'; \
			echo '[ -z ${IP_STATIC} ]|| \'; \
			echo '	sudo ip addr add ${IP_STATIC} dev em1'; \
			echo ''; \
			echo ''; \
			echo '# Record and log IPs (w/o Docker, loopback)'; \
			echo '#'; \
	    echo 'IP=$( hostname -I | \'; \
	    echo "  sed 's/\(172.17.[0-9]*.[0-9]*\)//' | \\"; \
	    echo "  sed 's/\(127.0.[0-9]*.[0-9]*\)//' \\"; \
	    echo ')'; \
	    echo 'echo ${IP} - $(date) >> ~/IP.log'; \
		) | tee ${START}; \
	fi
	chmod +x ${START}
}


# Configure ~/.bashrc, if necessary
if(! grep --quiet 'function dockin()' ${HOME}/.bashrc )
then
	( \
		echo ''; \
		echo '# Function to quickly enter containers'; \
		echo '#'; \
		echo 'function dockin()'; \
		echo '{'; \
		echo '  if [ $# -eq 0 ]'; \
		echo '  then'; \
		echo '		echo "Please pass a docker container to enter"'; \
		echo '		echo "Usage: dockin [containerToEnter]"'; \
		echo '	else'; \
		echo '		sudo docker exec -it $1 /bin/bash'; \
		echo '	fi'; \
		echo '}'; \
		echo ''; \
		echo '# Function to remove stopped containers and untagged images'; \
		echo '#'; \
		echo 'function dclean()'; \
		echo '{'; \
		echo '  sudo docker rm $(sudo docker ps -a -q)'; \
		echo "  sudo docker rmi $(sudo docker images | grep '^<none>' | awk '{print $3}')"; \
		echo '}'; \
		echo ''; \
		echo '# Aliases to frequently used functions and applications'; \
		echo '#'; \
		echo "alias c='dockin'"; \
		echo "alias d='sudo docker'"; \
		echo "alias e='sudo docker exec'"; \
		echo "alias i='sudo docker inspect'"; \
		echo "alias l='sudo docker logs -f'"; \
		echo "alias p='sudo docker ps -a'"; \
		echo "alias s='sudo docker ps -a | less -S'"; \
		echo "alias dstats='sudo docker stats $(sudo docker ps -a -q)'"; \
	) | tee -a ${HOME}/.bashrc; \
	echo ""; \
	echo ""; \
	echo "Please log in/out for changes to take effect!"; \
	echo ""; \
fi


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
	export DOCKER_GATEWAY="${DOCKER_GATEWAY} --dns-search=."


# If using RAM_REDUCE (,, = lowercase, bash 4+), then append to image options
#
[ "${RAM_REDUCE,,}" != "yes" ]|| \
	${IMG_OPS_DATABASE}+=" ${IMG_OPS_DATABASE_LOWRAM}"


# Run based on command
#
case "${COMMAND}" in
	"deploy"      ) docker_deploy;;
	"import"      ) docker_import;;
	"configure"   ) docker_configure;;
	*             ) usage_help;;
esac
