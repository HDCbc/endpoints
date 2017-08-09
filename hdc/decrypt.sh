#!/bin/bash
#
# Halt on errors or unset variables
#
set -eu


# Get name and path of this script, tracing symlinks
#
SOURCE="${BASH_SOURCE[0]}"
while [ -h "${SOURCE}" ]
do
	SOURCE="$( readlink ${SOURCE} )"
done


# Source config, in the parent directory of this (non-symlinked) script
#
PARENT_DIR="$( cd -P $( dirname "${SOURCE}" )/.. && pwd )"
. "${PARENT_DIR}"/config.env


# External HDD: if vars set and unmounted, then mount into empty dir
#
if ( \
	[ "${MOUNT_DEV}" ]&& \
	[ "${MOUNT_HDD}" ]&& \
	( ! grep -q "${MOUNT_DEV}" /proc/mounts )&& \
	( ! grep -q "${MOUNT_HDD}" /proc/mounts )
)
then
	sudo rm -rf "${MOUNT_HDD}"
	sudo mkdir -p "${MOUNT_HDD}"
	sudo mount "${MOUNT_DEV}" "${MOUNT_HDD}"
fi


# Data dir: if vars set and unmounted, then decrypt into empty dir
#
if ( \
	[ "${ENCRYPTED}" ]&& \
	[ "${VOLS_DATA}" ]&& \
	( ! grep -q "${ENCRYPTED}" /proc/mounts )&& \
	( ! grep -q "${VOLS_DATA}" /proc/mounts )
)
then
	sudo rm -rf "${VOLS_DATA}"
	sudo mkdir -p "${VOLS_DATA}"
	sudo /usr/bin/encfs --public "${ENCRYPTED}" "${VOLS_DATA}"
fi


# Alt Docker dir: if vars set and mounted, then make sure Docker uses them
#
if ( \
	[ "${MOUNT_DEV}" ]&& \
	[ "${MOUNT_HDD}" ]&& \
	( grep -q "${MOUNT_DEV}" /proc/mounts )&& \
	( grep -q "${MOUNT_HDD}" /proc/mounts )
)
then
	[ ! -d /var/lib/docker ]|| \
		sudo rm -rf /var/lib/docker
	sudo mkdir -p "${MOUNT_HDD}/docker"
	[ ! -L /var/lib/docker ]|| \
		sudo ln -s "${MOUNT_HDD}/docker" /var/lib/docker
	sudo sed -i "s|ExecStart=/usr/bin/dockerd -H fd://|ExecStart=/usr/bin/dockerd -g ${MOUNT_HDD}/docker -H fd://|" /lib/systemd/system/docker.service
fi


# Ensure correct permissions
#
sudo chown hdc:hdc "${VOLS_DATA}"
sudo chown -R exporter:exporter "${VOLS_DATA}"/import
sudo mkdir -p "${VOLS_DATA}"/mongo
sudo chmod 700 "${VOLS_DATA}"/import "${VOLS_DATA}"/mongo
sudo chmod 755 "${VOLS_DATA}"


# Reload and ensure Docker has started
#
if ( which systemctl )
then
	sudo systemctl daemon-reload
	sudo systemctl start docker
else
	sudo service docker restart
	sudo service docker start
fi


# Get Ethernet device name (filtered and keeping only one result)
#
ETHER_DEV="$( ifconfig | grep 'encap:Ethernet' | grep -v 'docker\|veth' | awk '{print $1}' )"
set -- "${ETHER_DEV}"
ETHER_DEV="${1}"


# Static IP - if vars set, Eth dev ID'd and not already is use
#
if (
	[ "${ETHER_DEV}" ]&& \
	[ "${IP_STATIC}" ]&& \
	( ! ping -c1 -w3 "${IP_STATIC}" )
)
then
	sudo ip addr add "${IP_STATIC}" dev "${ETHER_DEV}"
fi
