#!/bin/bash
#
# Halt on errors or unset variables
#
set -eu


# Verbose option
#
[ ! -z "${VERBOSE+x}" ]&&[ "${VERBOSE}" == true ]&& \
        set -x


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
	[ ! -d "${MOUNT_HDD}" ]|| \
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
	[ ! -d "${VOLS_DATA}" ]|| \
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
	( grep -q "\-g ${MOUNT_HDD}" /lib/systemd/system/docker.service )|| \
		sudo sed -i "s|ExecStart=/usr/bin/dockerd -H fd://|ExecStart=/usr/bin/dockerd -g ${MOUNT_HDD}/docker -H fd://|" /lib/systemd/system/docker.service
fi


# If var provided, redirect /var/lib/docker and set it in Docker config
#
if
	[ "${VL_DOCKER}" ]
then
	# If /var/lib/docker (not symlink), move it
	[ ! -d /var/lib/docker ]||[ -L /var/lib/docker ]|| \
		sudo mv /var/lib/docker "${VL_DOCKER}"

	# If no alias, create it
	[ -L /var/lib/docker ]|| \
		sudo ln -s "${VL_DOCKER}" /var/lib/docker

	# Not redirect not in docker.service, add it
	( grep -q "\-g ${VL_DOCKER}" /lib/systemd/system/docker.service )|| \
		sudo sed -i "s|ExecStart=/usr/bin/dockerd -H fd://|ExecStart=/usr/bin/dockerd -g ${VL_DOCKER} -H fd://|" /lib/systemd/system/docker.service
fi


# Limit Docker pulls to one at a time
#
if ( ! grep -q "\-\-max\-concurrent\-downloads" /lib/systemd/system/docker.service )
then
	sudo sed -i '/^ExecStart=\/usr\/bin\/dockerd/ s/$/ --max-concurrent-downloads 1/' /lib/systemd/system/docker.service
fi


# Ensure correct permissions
#
sudo chown hdc:adm "${VOLS_DATA}"
sudo chown -R exporter:exporter "${VOLS_DATA}"/import
sudo mkdir -p "${VOLS_DATA}"/mongo
sudo chmod 700 "${VOLS_DATA}"/import "${VOLS_DATA}"/mongo
sudo chmod 755 "${VOLS_DATA}"


# Reload and ensure Docker has started
#
if ( which systemctl >/dev/null 2>&1 )
then
	sudo systemctl daemon-reload
	sudo systemctl start docker
else
	sudo service docker restart
fi


# Get Ethernet device name (filtered and keeping only one result)
#
ETHER_DEV=$( ip -o link show | grep -v 'vbox\|veth\|br-' | awk '{print $2,$9}' | grep UP | awk '{print $1}' | sed 's/://' | head -n1 ); \


# Static IP - if vars set, Eth dev ID'd and not already is use
#
if (
	[ "${ETHER_DEV}" ]&& \
	[ "${IP_STATIC}" ]&& \
	( ! ping -c1 -w3 "${IP_STATIC}" >/dev/null 2>&1 )
)
then
	sudo ip addr add "${IP_STATIC}" dev "${ETHER_DEV}"
fi
