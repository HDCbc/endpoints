#!/bin/bash
#
set -x


# Pull repo and ensure mounts
#
git -C /hdc/endpoint pull
/hdc/endpoint/hdc/decrypt.sh


# Stop Docker containers and Docker
#
sudo docker rm -fv $( sudo docker ps -a -q )
sudo service docker stop


# Backup and unmount data folder
#
sudo mkdir -p /hdc/bk
sudo mv /hdc/data/* /hdc/bk/data
sudo umount /hdc/data/


# Unmount and backup encrypted folder
#
sudo umount /hdc/.encrypted/
sudo mv /hdc/.encrypted /hdc/bk/encrypted


# Remount
#
/hdc/endpoint/hdc/decrypt.sh


# Backup config.env and cat IDs
#
sudo mv /hdc/endpoint/config.env /hdc/bk
cat /hdc/bk/config.env | grep "GATEWAY_ID\|DOCTOR_IDS"
echo
echo "Record IDs.  Press Enter to continue."
read -s ENTER_TO_CONTINUE


# Replace config.env and SQL import script
#
cd /hdc/endpoint
make env
make scheduled-import


# Replace monit config and import/export user
#
cd /hdc/endpoint/hdc
make monit
sudo userdel exporter
make user


# Upgrade and cleanup
#
sudo apt update
sudo apt upgrade -y -o Dpkg::Options::="--force-confnew"
sudo apt dist-upgrade -y
sudo apt autoremove -y


# Reapply Docker config
#
sudo sed -i '/![^#]/ s/\(^start on.*$$\)/#\ \1/' /etc/init/docker.conf
sudo sed -i "s|ExecStart=/usr/bin/dockerd -H fd://|ExecStart=/usr/bin/dockerd -g /hdc/.hdd/docker -H fd://|" \
  /lib/systemd/system/docker.service


# Reboot, but only after a successful update-grub
#
sudo update-grub && \
  sudo reboot
