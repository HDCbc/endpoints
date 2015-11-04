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


# Output rejection message and exit
#
inform_exit ()
{
	# Expects one error string
	echo
	echo $1
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


# Output usage instructions and quit
#
usage_error ()
{
	# Expects one usage string
	inform_exit "Usage: ./endpoint.sh $1"
}


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
	echo "	testgroup   Run a new Gateway with a sencond test Gateway"
	echo "	import      Run and then remove an OSCAR_E2E importer"
	echo "	configure   Configures Docker, MongoDB and bash"
	echo "	keygen      Run a keyholder for SSH keys"
	echo
	exit
}


# Verify the status of id_rsa, id_rsa.pub and known_hosts
#
docker_keygen ()
{
	# Only create keyholder if necessary
	STATUS_KEYHOLDER=$( sudo docker inspect -f {{.State.Running}} ${NAME_KEYHOLDER} ) || true
	if( ${STATUS_KEYHOLDER} = "true" )
	then
		echo "NOTE: Updates should reuse existing ssh keys"
	else
	{
		# Create data container for ssh details
		inform_exec "Running keyholder" \
			"sudo docker run -d ${RUN_KEYHOLDER}"

		# Echo public key
		echo
		echo "New SSH files generated.  Please take note of the public key."
		echo
		sudo docker exec ${NAME_KEYHOLDER} /bin/bash -c \
			'ssh-keygen -b 4096 -t rsa -N "" -C dkey${gID}-$(date +"%Y-%m-%d-%T") -f ~/.ssh/id_rsa'
		sudo docker exec ${NAME_KEYHOLDER} /bin/bash -c 'cat /root/.ssh/id_rsa.pub'
		echo
		echo

		# Test the key, generating a known_hosts file, otherwise remove container
		echo "Copy that key over, then press Enter to test it"
		echo
		read ENTER_TO_CONTINUE
		sudo docker exec -ti ${NAME_KEYHOLDER} /bin/bash -c \
			'ssh -p ${PORT_AUTOSSH} autossh@${IP_HUB} -o StrictHostKeyChecking=no "hostname; exit"'

		# Copy files to expected location
		sudo docker exec ${NAME_KEYHOLDER} /bin/bash -c 'mkdir -p /home/autossh/.ssh/'
		sudo docker exec ${NAME_KEYHOLDER} /bin/bash -c 'cp /root/.ssh/* /home/autossh/.ssh/'
		sudo docker exec ${NAME_KEYHOLDER} /bin/bash -c 'cp /root/.ssh/* /home/autossh/.ssh/'
		echo
		echo
		echo "Success!"
		echo
		echo
	}
	fi
}


# Run a database and set the index (duplicates)
#
docker_database ()
{
	sudo docker pull mongo
	sudo docker run -d ${RUN_DATABASE} || \
		echo "NOTE: Updates should reuse existing databases"

	sleep 5
	sudo docker exec -ti ${NAME_DATABASE} /bin/bash -c \
		"mongo query_gateway_development --eval \
  	'printjson( db.records.ensureIndex({ hash_id : 1 }, { unique : true }))'"
}


# Run a new gateway and add populate providers.txt
#
docker_gateway ()
{
	sudo docker rm -fv ${NAME_GATEWAY} || true

	sudo docker pull ${REPO_GATEWAY}
	inform_exec "Running gateway" \
		"sudo docker run -d ${RUN_GATEWAY}"

	sudo docker exec -ti ${NAME_GATEWAY} /bin/bash -c \
		'/sbin/setuser autossh ssh -p ${PORT_AUTOSSH} autossh@${IP_HUB} -o StrictHostKeyChecking=no "hostname; exit"'

	[ -z ${DOCTOR_IDS} ]|| \
		sudo docker exec -ti ${NAME_GATEWAY} /app/providers.sh add ${DOCTOR_IDS}
}


# Run a gateway and database containers
#
docker_deploy ()
{
	docker_configure
	docker_keygen
	docker_database
	docker_gateway
}


# Run deployment, but add a second test gateway
#
docker_testgroup ()
{
	NAME_GATEWAY=${NAME_GATEWAY}-testgroup
	IP_HUB=142.104.128.121
	RUN_GW_BASE="--name ${NAME_GATEWAY} -h ${NAME_GATEWAY} --restart='always'"
	RUN_GW_VARS="-e gID=${GATEWAY_ID} -e IP_HUB=${IP_HUB} -e PORT_AUTOSSH=${PORT_AUTOSSH}"
	RUN_GATEWAY="${RUN_GW_BASE} ${RUN_GW_LINKS} ${RUN_GW_VOLS} ${RUN_GW_VARS} ${REPO_GATEWAY}"

	#Provide directions for adding a gateway on the test network
	echo "To add a test network gateway use the following:"
	echo
	echo "sudo docker run -d ${RUN_GATEWAY}"
	echo
	echo "sudo docker exec -ti ${NAME_GATEWAY} /app/providers.sh add ${DOCTOR_IDS}"
	echo
	echo "sudo docker exec -ti ${NAME_GATEWAY} /sbin/setuser autossh ssh -p ${PORT_AUTOSSH} autossh@${IP_HUB} -o StrictHostKeyChecking=no \"hostname; exit\""
	echo
	echo
	exit
}


# Import an OSCAR SQL dump, containers not persistent
#
docker_oscar ()
{
	# Make sure the Gateway is up
	STATUS_GATEWAY=$( sudo docker inspect -f {{.State.Running}} ${NAME_GATEWAY} ) || true
	[ ${STATUS_GATEWAY} = "true" ]|| \
		docker_deploy

	sudo docker rm -fv ${NAME_OSCAR} || true
	sudo docker pull ${REPO_OSCAR}

	sudo docker run -t ${RUN_OSCAR} || true
	sudo docker rm -fv ${NAME_OSCAR}
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


	# Reduce swap usage (swappiness)
	echo 0 | sudo tee /proc/sys/vm/swappiness
        if(! grep --quiet 'vm.swappiness = 0' /etc/sysctl.conf )
        then
                ( \
                        echo ''; \
                        echo '# Reduce swap usage'; \
                        echo 'vm.swappiness.conf'; \
                ) | sudo tee -a /etc/sysctl.conf; \
        fi


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
		) | tee -a ${HOME}/.bashrc; \
		echo ""; \
		echo ""; \
		echo "Please log in/out for changes to take effect!"; \
		echo ""; \
	fi


	# Create OSP account
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
[ "${DNS_DISABLE,,}" != "yes" ] || \
	export DOCKER_GATEWAY="${DOCKER_GATEWAY} --dns-search=."


# Run based on command
#
case "${COMMAND}" in
	"deploy"      ) docker_deploy;;
	"testgroup"   ) docker_testgroup;;
	"import"      ) docker_oscar;;
	"configure"   ) docker_configure;;
	"keygen"      ) docker_keygen;;
	*             ) usage_help;;
esac

echo
echo "Done!  Please remember to source ~/.bashrc if changes were made."
echo
