################
# General Jobs #
################

default: deploy

hdc: hdc-prep deploy upgrade-reboot


###################
# Individual jobs #
###################

# Check prerequisites, pull/build and deploy containers, then test ssh keys
deploy: env config-docker config-mongodb
	@	[ $(MODE) != "dev" ]||[ -s ./docker/dev.yml ] || \
			sudo cp ./docker/dev.yml-sample ./docker/dev.yml
	. ./config.env; \
		sudo TAG=$(TAG) VOLS_CONFIG=$${VOLS_CONFIG} VOLS_DATA=$${VOLS_DATA} docker-compose $(YML) pull; \
		sudo TAG=$(TAG) VOLS_CONFIG=$${VOLS_CONFIG} VOLS_DATA=$${VOLS_DATA} docker-compose $(YML) build; \
		sudo TAG=$(TAG) VOLS_CONFIG=$${VOLS_CONFIG} VOLS_DATA=$${VOLS_DATA} docker-compose $(YML) up -d
	@	sudo docker exec gateway /ssh_test.sh


# Additional setup for HDC managed solutions
hdc-prep: hdc-ssh config-docker
	@	$(MAKE) -C hdc


# Create HDC ssh key at beginning of setup, for convenience
hdc-ssh: env
	$(MAKE) ssh -C hdc


# Configures and sources environment, used as a prerequisite
env:
	@	if ! [ -s ./config.env ]; \
		then \
		        cp ./config.env-sample ./config.env; \
		        nano config.env; \
		fi


# Docker and Docker Compose installs
config-docker:
	@	which docker-compose || wget -qO- https://raw.githubusercontent.com/HDCbc/devops/master/deploy/docker_setup.sh | sh


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


# Apply final settings and reboot
upgrade-reboot:
	@	sudo apt-get update
	@	sudo apt-get upgrade -y
	@	sudo apt-get dist-upgrade -y
	@	sudo update-grub
	@	sudo reboot now


# Import Sample10 data into a Gateway
sample-data:
	@	sudo docker exec gateway /gateway/util/sample10/import.sh || true


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
