################
# General Jobs #
################

default: config-mongodb deploy sample-data

configure: config-docker config-mongodb

queries: query-importer


###################
# Individual jobs #
###################

# Check prerequisites, pull/build and deploy containers, then test ssh keys
deploy:
	@	which docker-compose || make config-docker
	@	[ $(MODE) != "dev" ] || \
			[ -s ./dev/dev.yml ] || \
			sudo cp ./dev/dev.yml-sample ./dev/dev.yml
	@	sudo TAG=$(TAG) VOLS=${VOLS} docker-compose $(YML) pull
	@	sudo TAG=$(TAG) VOLS=${VOLS} docker-compose $(YML) build
	@	sudo TAG=$(TAG) VOLS=${VOLS} docker-compose $(YML) up -d
	@	sudo docker exec gateway /ssh_test.sh

config-docker:
	@	wget -qO- https://raw.githubusercontent.com/HDCbc/devops/master/docker/docker_setup.sh | sh

config-mongodb:
	@	( echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled )> /dev/null
	@	( echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag )> /dev/null
	@	if(! grep --quiet 'never > /sys/kernel/mm/transparent_hugepage/enabled' /etc/rc.local ); \
		then \
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
		fi; \
		sudo chmod 755 /etc/rc.local

sample-data:
	@	sudo docker exec gateway /gateway/util/sample10/import.sh || true


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


################
# Runtime prep #
################

# Source and set variables
#
include ./config.env


# Default tag and volume path
#
TAG  ?= latest
MODE ?= prod
VOLS ?= /hdc


# Default YML is docker-compose.yml
#
YML ?= -f ./docker-compose.yml
ifeq ($(MODE),dev)
	YML += -f ./dev/dev.yml
endif
