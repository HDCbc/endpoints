########
# Jobs #
########

default: configure deploy

endpoint: pdc-user pdc-start

# Check ssh keys, then pull build and deploy using docker compose
deploy:
	@	if [ "$$( sudo ssh -i ${PATH_SSH}/id_rsa -p ${PORT_AUTOSSH} autossh@${IP_COMPOSER} \
				-o UserKnownHostsFile=${PATH_SSH}/known_hosts /app/test/ssh_landing.sh )" ]; \
		then \
			TAG=${TAG:-prod}; \
			set -e; \
			sudo TAG=$(TAG) PATH_PRIVATE=${PATH_PRIVATE} docker-compose $(YML) pull; \
			sudo TAG=$(TAG) PATH_PRIVATE=${PATH_PRIVATE} docker-compose $(YML) build; \
			sudo TAG=$(TAG) PATH_PRIVATE=${PATH_PRIVATE} docker-compose $(YML) up -d; \
		else \
			echo; \
			echo "ERROR: Unable to connect to autossh@${IP_COMPOSER}."; \
			echo; \
			echo "Create/configure keys in ${PATH_SSH} or run 'make ssh'."; \
			echo; \
		fi


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
	@	[ $$(getent passwd import) ]|| \
			sudo useradd -m -d ${PATH_IMPORT} -c "OSP Export Account" -s /bin/bash exporter

# Create start script and defer Docker load, for PDC-managed endpoints
pdc-start:
	@	sudo sed -i '/![^#]/ s/\(^start on.*$\)/#\ \1/' /etc/init/docker.conf
	@	START=${HOME}/ep-start.sh; \
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
			echo '[ $( pgrep -c docker ) -gt 0 ]|| \'; \
	    echo '	sudo service docker start'; \
			echo ''; \
			echo ''; \
			echo '# Add static IP, if provided in env file'; \
			echo '#'; \
			echo '. '${SCRIPT_DIR}'/config.env'; \
			echo 'IP_STATIC=${IP_STATIC:-"."}'; \
			echo '[ $( hostname -I )| grep ${IP_STATIC} ]|| \'; \
			echo '	sudo ip addr add ${IP_STATIC} dev em1'; \
		) | tee ${START}; \
		chmod +x ${START}


#############
# Variables #
#############

# Source and set variables
#
include ./config.env
#
PORT_AUTOSSH ?= 2774
IP_COMPOSER  ?= 142.104.128.120
PATH_PRIVATE ?= /encrypted/
PATH_IMPORT   = $(PATH_PRIVATE)/import/
PATH_SSH      = $(PATH_PRIVATE)/ssh/


# Default tag and moeeis prod, rename master to latest (~same)
#
TAG ?= prod
ifeq ($(TAG),master)
	TAG=latest
endif


# Set .YML files
#
YML=-f ./docker-compose.yml
ifeq ($(MODE),dev)
	YML+= -f ./dev/dev.yml
endif
