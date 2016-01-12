########
# Jobs #
########

default: configure deploy

endpoint: pdc-user pdc-start

# Pull image, deploy container (using config) and test ssh
deploy:
		sudo docker pull ${DOCKER_IMAGE}
		sudo docker stop ${DOCKER_NAME} || true
		sudo docker rm ${DOCKER_NAME} || true
		sudo docker run -d --name=${DOCKER_NAME} --restart=always --log-driver=syslog \
			-v ${PATH_VOLUMES}:/volumes/ --env-file=./config.env ${DOCKER_IMAGE}
		sudo docker exec ${DOCKER_NAME} /ssh_test.sh


# Build image, deploy container (using config) and test ssh
dev:
		sudo docker rm -fv ${DOCKER_NAME} || true
		sudo docker build -t local/endpoint .
		sudo docker run -d --name=${DOCKER_NAME} --restart=always --log-driver=syslog \
			-v ${PATH_VOLUMES}:/volumes/ --env-file=./config.env local/endpoint
		sudo docker exec ${DOCKER_NAME} /ssh_test.sh


# Run PDC-standard Docker setup
configure:
	@	wget -qO- https://raw.githubusercontent.com/PDCbc/devops/master/docker_setup.sh | sh


# Make and test ssh keys, can be provided ahead of time
ssh:
	@	sudo mkdir -p ${PATH_SSH}
	@	sudo ssh-keygen -b 4096 -t rsa -N "" -C ep${GATEWAY_ID}-$$(date +%Y-%m-%d-%T) -f ${PATH_SSH}/id_rsa || true
	@	cat ${PATH_SSH}/id_rsa.pub
	@	echo
	@	echo "Please provide ${PATH_SSH}/id_rsa.pub (above), a list of participating"
	@	echo "physician CPSIDs and all paperwork to the PDC at admin@pdcbc.ca."
	@	echo


# Create import user, for PDC-managed endpoints
pdc-user:
	@	sudo mkdir -p ${PATH_IMPORT}
	@	[ "$$( getent passwd exporter )" ]|| \
			sudo useradd -m -d ${PATH_IMPORT} -c "OSP Export Account" -s /bin/bash exporter


# Create start script and defer Docker load, for PDC-managed endpoints
pdc-start:
	@	sudo sed -i '/![^#]/ s/\(^start on.*$$\)/#\ \1/' /etc/init/docker.conf
	@	START=$${HOME}/ep-start.sh; \
	  ( \
			echo '#!/bin/bash'; \
			echo '#'; \
			echo 'set -e -o nounset'; \
			echo ''; \
			echo ''; \
			echo '# Decrypt /encrypted/'; \
			echo '#'; \
			echo '[ -s /encrypted/docker/config.env ]|| \'; \
	    echo '	sudo /usr/bin/encfs --public /.encrypted /encrypted'; \
			echo ''; \
			echo ''; \
			echo '# Start Docker'; \
			echo '#'; \
			echo '[ $$( pgrep -c docker ) -gt 0 ]|| \'; \
	    echo '	sudo service docker start'; \
			echo ''; \
			echo ''; \
			echo '# Add static IP, if provided in env file'; \
			echo '#'; \
			echo '. '$${HOME}'/config.env'; \
			echo 'IP_STATIC=$${IP_STATIC:-"."}'; \
			echo '[ $$( hostname -I )| grep $${IP_STATIC} ]|| \'; \
			echo '	sudo ip addr add $${IP_STATIC} dev em1'; \
		) | tee $${START}; \
		chmod +x $${START}


#############
# Variables #
#############

# Source and set variables
#
include ./config.env
#
DOCKER_IMAGE  ?= pdcbc/endpoint_oscar:prod
DOCKER_NAME   ?= endpoint
IP_COMPOSER   ?= 142.104.128.120
PORT_AUTOSSH  ?= 2774
PATH_VOLUMES  ?= /encrypted/volumes
PATH_IMPORT    = $(PATH_VOLUMES)/import/
PATH_SSH       = $(PATH_VOLUMES)/ssh/
