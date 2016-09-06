################
# General Jobs #
################

default: deploy

hdc: hdc-ssh hdc-user hdc-packages hdc-firewall hdc-encrypt deploy


###################
# Individual jobs #
###################


# Check prerequisites, pull/build and deploy containers, then test ssh keys
deploy: config-docker config-mongodb
	@	which docker-compose || make config-docker
	@	[ $(MODE) != "dev" ] || \
			[ -s ./docker/dev.yml ] || \
			sudo cp ./docker/dev.yml-sample ./docker/dev.yml
		. ./config.env; \
		sudo TAG=$(TAG) VOLS_CONFIG=$${VOLS_CONFIG} VOLS_DATA=$${VOLS_DATA} docker-compose $(YML) pull; \
		sudo TAG=$(TAG) VOLS_CONFIG=$${VOLS_CONFIG} VOLS_DATA=$${VOLS_DATA} docker-compose $(YML) build; \
		sudo TAG=$(TAG) VOLS_CONFIG=$${VOLS_CONFIG} VOLS_DATA=$${VOLS_DATA} docker-compose $(YML) up -d
	@	sudo docker exec -ti gateway /ssh_test.sh


# Docker and Docker Compose installs, used as a prerequisite
config-docker:
	@	which docker-compose || wget -qO- https://raw.githubusercontent.com/HDCbc/devops/master/docker/docker_setup.sh | sh


# Disable Transparent Hugepage, for MongoDb
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


# Import Sample10 data into a Gateway
sample-data:
	@	sudo docker exec gateway /gateway/util/sample10/import.sh || true


# Configures and sources environment, used as a prerequisite
env:
	@	if ! [ -s ./config.env ]; \
		then \
		        cp ./config.env-sample ./config.env; \
		        nano config.env; \
		fi


# Stop Docker at boot for Ubuntu 14.04 (docker.conf) and 16.04 (systemd)
hdc-config-docker:
	@	sudo sed -i '/![^#]/ s/\(^start on.*$$\)/#\ \1/' /etc/init/docker.conf
	@	sudo systemctl disable docker || true


# Monit config for HDC managed solution
hdc-config-monit: env hdc-packages
	@	sudo cp ./hdc/monit_* /etc/monit/conf.d/
	@	sudo cat /etc/monit/conf.d/monit_*
	@	. ./config.env; \
		sudo sed -i "s/44xxx/`expr 44000 + $${GATEWAY_ID}`/" /etc/monit/conf.d/monit_*
		if( sudo grep --quiet "# set httpd port 2812 and" /etc/monit/monitrc ); \
		then \
		sudo sed -i \
			-e "/include \/etc\/monit\/conf-enabled\// s/^/#/" \
			-e "/set httpd port 2812 and/s/^#//g" \
			-e "/use address localhost/s/^#//g" \
			-e "/allow localhost/s/^#//g" \
			/etc/monit/monitrc; \
		fi
		sudo monit reload


# Encrypt, stop Docker boot and add decrypt.sh for HDC managed solution
hdc-encrypt: hdc-packages hdc-config-docker
	@	sudo cp hdc/decrypt.sh /hdc/
	@	sudo docker stop gateway_db || true
	@	if [ ! -d "/hdc/.encrypted" ]; \
		then \
			sudo mkdir -p /hdc/.encrypted /hdc/data; \
			sudo encfs --public /hdc/.encrypted /hdc/data; \
		fi
	@	sudo chmod a+rx /hdc/.encrypted /hdc/data


# Firewall, limit to HDC servers for HDC managed solution
hdc-firewall: hdc-packages
	@	sudo ufw allow from 142.104.128.120
	@	sudo ufw allow from 142.104.128.121
	@	sudo ufw allow from 149.56.154.244
	@	sudo ufw --force enable
	@	sudo ufw status verbose


# Packages required for HDC managed solution
# TODO: switch to apt (not apt-get) when Ubuntu 14.04 is dropped
hdc-packages: config-docker
	@	PACKAGES="autossh encfs monit ufw"; \
		MISSING=0; \
		for p in $${PACKAGES}; \
		do \
			which $${p} || MISSING=1; \
		done;\
		if [ $${MISSING} -gt 0 ]; \
		then \
			sudo apt-get update; \
			sudo apt-get install $${PACKAGES} -y; \
		fi


# SSH key creation and testing for HDC managed solution
hdc-ssh: env
	@	. ./config.env; \
		if( sudo test ! -e /root/.ssh/id_rsa ); \
		then \
		    sudo ssh-keygen -b 4096 -t rsa -N \"\" -C ep${GATEWAY_ID}-$$(date +%Y-%m-%d-%T) -f /root/.ssh/id_rsa; \
		fi
	@	if ( sudo ssh -p 2774 142.104.128.120 /app/test/ssh_landing.sh ); \
		then \
	        echo 'Connection succesful!'; \
		else \
	        echo; \
	        sudo cat /root/.ssh/id_rsa.pub; \
	        echo; \
	        echo 'ERROR: unable to connect to 142.104.128.120'; \
	        echo; \
	        echo 'Please verify the ssh public key (above) has been provided to admin@hdcbc.ca.'; \
			sleep 5; \
		fi


# User for HDC managed solution
hdc-user: env
	@	. ./config.env; \
		[ "$$( getent passwd exporter )" ]|| \
			sudo useradd -m -d ${VOLS_CONFIG}/import -c "OSP Export Account" -s /bin/bash exporter


################
# Runtime prep #
################


# Default tag (e.g. latest, dev, 0.1.2) and build mode (e.g. prod, dev)
#
TAG  ?= latest
MODE ?= prod


# Default is docker-compose.yml, add dev.yml for development
#
YML ?= -f ./docker/deploy.yml
ifeq ($(MODE),dev)
	YML += -f ./docker/dev.yml
endif
