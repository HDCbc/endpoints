################
# General Jobs #
################

default: ssh packages monit firewall ip kangaroo encrypt user


###################
# Individual jobs #
###################

# Monit config
monit: packages ssh
	@	sudo cp ./monit_* /etc/monit/conf.d/
	@	sudo cat /etc/monit/conf.d/monit_autossh
	@	. ../config.env; \
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
	@	sudo monit reload
	@	sleep 2
	@	sudo monit start autossh


# Sysstat config
sysstat: packages
	@	sudo sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
	@	if( which systemctl ); \
		then \
			sudo systemctl restart sysstat; \
		else \
			sudo service sysstat restart || true ; \
		fi


# For InFocus Kangaroo Mobile Desktop Pro hardware
# Stop Ubuntu (15.10+) renaming eth0, remove unattended-upgrades and nuke/mount HDD in dock
kangaroo: packages
	@	if( ! sudo grep --quiet 'NAME="eth0"' /lib/udev/rules.d/*.rules ); \
		then \
			( \
				echo 'SUBSYSTEM=="net", ACTION=="add", DRIVERS=="asix", ATTR{address}=="?*", ATTR{dev_id}=="0x0", ATTR{type}=="1", NAME="eth0"'; \
			) | sudo tee -a /lib/udev/rules.d/60-persistent-net.rules; \
		fi
	@	if( ! sudo grep --quiet 'iface eth0 inet dhcp' /etc/network/interfaces ); \
		then \
			( \
			echo ''; \
			echo '# The primary network interface'; \
			echo 'auto eth0'; \
			echo 'iface eth0 inet dhcp'; \
			) | sudo tee -a /etc/network/interfaces; \
		fi
	@	if ( which unattended-upgrades ); \
		then \
			sudo apt-get purge -y unattended-upgrades; \
			sudo rm -rf /var/log/unattended-upgrades; \
		fi
	@	. ../config.env; \
		if [ ! -z "$${MOUNT_DEV}" ]&&( ! sudo grep --quiet "$${MOUNT_DEV} $${MOUNT_HDD}" /proc/mounts ); \
		then \
			sudo parted -a optimal /dev/sda mktable gpt; \
			sudo parted /dev/sda mkpart ext2 0% 100%; \
			sleep 2; \
			sudo mkfs.ext2 /dev/sda1; \
			sudo mkdir -p "$${MOUNT_HDD}"; \
			sudo mount "$${MOUNT_DEV}" "$${MOUNT_HDD}"; \
		fi


# Encrypt, stop Docker at boot, move Docker dir to $VOLS_DATA and add decrypt.sh
# Note: docker.conf for Ubuntu 14.04 and systemctl for Ubuntu 16.04
encrypt: packages kangaroo
	@	if( which systemctl ); \
		then \
			sudo systemctl disable docker; \
			sudo systemctl stop docker; \
		else \
			sudo sed -i '/![^#]/ s/\(^start on.*$$\)/#\ \1/' /etc/init/docker.conf; \
			sudo service docker stop || true ; \
		fi
	@	sudo docker stop gateway_db || true
	@	[ ! -e /hdc/decrypt.sh ]|| sudo rm /hdc/decrypt.sh
	@	sudo ln -s $$( pwd )/decrypt.sh /hdc/decrypt.sh
	@	. ../config.env; \
		if [ ! -z "$${VOLS_DATA}" ]; \
		then \
			sudo mkdir -p "$${ENCRYPTED}" "$${VOLS_DATA}"; \
			sudo encfs -o nonempty --public "$${ENCRYPTED}" "$${VOLS_DATA}"; \
		fi; \
		sudo chmod a+rx "$${ENCRYPTED}" "$${VOLS_DATA}"
	@	. ../config.env; \
		if [ ! -z "$${MOUNT_HDD}" ]; \
		then \
			sudo sed -i "s|ExecStart=/usr/bin/dockerd -H fd://|ExecStart=/usr/bin/dockerd -g $${MOUNT_HDD}/docker -H fd://|" /lib/systemd/system/docker.service; \
		fi; \
		if [ ! -z "$${MOUNT_HDD}" ]&&[ ! "$$( sudo ls -A $${MOUNT_HDD}/docker )" ]&&[ ! -h /var/lib/docker ]; \
		then \
			sudo umount /var/lib/docker/devicemapper/mnt/*; \
			sudo mv /var/lib/docker "$${MOUNT_HDD}/docker"; \
			sudo ln -s "$${MOUNT_HDD}/docker" /var/lib/docker; \
		fi
	@	if( which systemctl ); \
		then \
			sudo systemctl daemon-reload; \
			sudo systemctl reload docker; \
			sudo systemctl restart docker || true; \
		else \
			sudo service docker start || true ; \
		fi


# Firewall, limit to HDC server, Mist servers and Vagrant (if applicable)
firewall: packages
	@	sudo ufw allow from 142.104.128.120
	@       sudo ufw allow from 104.198.19.203
	@       sudo ufw allow from 35.184.67.94
	@       sudo ufw allow from 104.198.197.230
	@       sudo ufw allow from 104.154.33.164
	@       sudo ufw allow from 104.155.147.47
	@	sudo ufw allow ssh
	@	[ ! -d /vagrant ]|| \
			sudo ufw allow from 10.0.2.2
	@	sudo ufw --force enable
	@	sudo ufw status verbose


# Set and maintain static IP, from config.env
ip:
	. ../config.env; \
	ETHER_DEV=$$( ip -o link show | grep -v 'vbox\|veth\|br-' | awk '{print $$2,$$9}' | grep UP | awk '{print $$1}' | \
		sed 's/://' | head -n1 ); \
	if( ! sudo crontab -l | grep "ip addr add" ); \
	then \
		( \
			sudo crontab -l; \
			echo ""; \
			echo "# Keep Static IP Active"; \
			echo "0 * * * * ip addr add $${IP_STATIC} dev $${ETHER_DEV}"; \
		) | sudo crontab -; \
	fi


# Packages - TODO: switch to apt (not apt-get) when Ubuntu 14.04 is dropped
packages:
	@	PACKAGES="autossh encfs lynx monit nano parted python realpath secure-delete sysstat ufw"; \
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


# SSH key creation and testing
ssh:
	@	. ../config.env; \
		if( sudo test ! -e /root/.ssh/id_rsa ); \
		then \
		    sudo ssh-keygen -b 4096 -t rsa -N "" -C ep$${GATEWAY_ID}-$$(date +%Y-%m-%d-%T) -f /root/.ssh/id_rsa; \
		fi
	@	. ../config.env; \
		if( test ! -e $${VOLS_DATA}/ssh/id_rsa ); \
		then \
			sudo mkdir -p $${VOLS_CONFIG}/ssh/; \
			sudo cp /root/.ssh/id_rsa /root/.ssh/id_rsa.pub $${VOLS_CONFIG}/ssh/; \
			sudo chown -R $$(whoami):$$(whoami) $${VOLS_CONFIG}; \
		fi
	@	if ( sudo ssh -p 2774 142.104.128.120 -o BatchMode=yes -o StrictHostKeyChecking=no /app/test/ssh_landing.sh ); \
		then \
	        echo 'Connection succesful!'; \
		else \
	        echo; \
	        sudo cat /root/.ssh/id_rsa.pub; \
	        echo; \
	        echo 'ERROR: unable to connect to 142.104.128.120'; \
	        echo; \
	        echo 'Please verify the ssh public key (above) has been provided to admin@hdcbc.ca.'; \
			sleep 15; \
		fi


# Import export user and current/admin user ~/.bashrc
user:
	@	. ../config.env; \
		[ "$$( getent passwd exporter )" ]|| \
			sudo useradd -m -d "$${VOLS_DATA}"/import -c "OSP Export Account" -s /bin/bash exporter; \
		sudo mkdir -p "$${VOLS_DATA}"/import/.ssh; \
		sudo touch "$${VOLS_DATA}"/import/.ssh/authorized_keys; \
		sudo chown -R exporter:exporter "$${VOLS_DATA}"; \
		sudo chmod 644 "$${VOLS_DATA}"/import/.ssh/authorized_keys
		if( ! sudo grep --quiet "cd /hdc/" ~/.bashrc ); \
		then \
			( \
				echo ''; \
				echo '# Start in /hdc/'; \
				echo '#'; \
				echo 'cd /hdc/'; \
			) >> ~/.bashrc; \
		fi


# Scrub folder, if specified in config.env
scrub: packages
	@	sudo service docker stop || true
	@	. ../config.env; \
		( ! sudo grep --quiet "$${MOUNT_DEV}" /proc/mounts )|| \
			sudo umount "$${MOUNT_DEV}"; \
		( ! sudo grep --quiet "$${MOUNT_HDD}" /proc/mounts )|| \
			sudo umount "$${MOUNT_HDD}"; \
		[ -z "$${VOLS_DATA}" ]|| \
			sudo srm -rfll $${VOLS_DATA}


# Scrub external HDD, if specified in config.env
scrub-dev:
	@	sudo service docker stop || true
	@	. ../config.env; \
		( ! sudo grep --quiet "$${MOUNT_DEV}" /proc/mounts )|| \
			sudo umount "$${MOUNT_DEV}"; \
		( ! sudo grep --quiet "$${MOUNT_HDD}" /proc/mounts )|| \
			sudo umount "$${MOUNT_HDD}"; \
		[ -z "$${MOUNT_DEV}" ]|| \
			sudo shred -vfzn 1 $${MOUNT_DEV}


# Source config.env - configured manually or with make in parent dir
include ../config.env
