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


# External HDD - if vars set and unmounted, then mount into empty dir
#
if ! ( \
	[ -z "${MOUNT_DEV}" ]|| \
	[ -z "${MOUNT_HDD}" ]|| \
	( grep -q "${MOUNT_DEV}" /proc/mounts )|| \
	( grep -q "${MOUNT_HDD}" /proc/mounts )
)
then
	[ ! -d "${MOUNT_HDD}" ]|| \
		sudo rm -rf "${MOUNT_HDD}" && sudo mkdir -p "${MOUNT_HDD}"
	sudo mount "${MOUNT_DEV}" "${MOUNT_HDD}"
fi


# Data dir - if vars set and unmounted, then decrypt into empty dir
#
if ! ( \
	[ -z "${ENCRYPTED}" ]|| \
	[ -z "${VOLS_DATA}" ]|| \
	( grep -q "${ENCRYPTED}" /proc/mounts )|| \
	( grep -q "${VOLS_DATA}" /proc/mounts )
)
then
	[ ! -d "${VOLS_DATA}" ]|| \
		sudo rm -rf "${VOLS_DATA}" && sudo mkdir -p "${VOLS_DATA}"
	sudo /usr/bin/encfs --public "${ENCRYPTED}" "${VOLS_DATA}"
	sudo chown -R root:root "${VOLS_DATA}"
	sudo chmod -R 755 "${VOLS_DATA}"
	sudo mkdir -p "${VOLS_DATA}"/import
	sudo chown -R exporter:exporter "${VOLS_DATA}"/import
fi


# Alt Docker dir - if vars set and /var/lib/docker not a symlink, then delete it
#
if ( \
	[ "${MOUNT_DEV}" ]&& \
	[ "${MOUNT_HDD}" ]&& \
	[ -d /var/lib/docker ]&& \
	[ ! -L /var/lib/docker ]
)
then
	sudo rm -rf /var/lib/docker
fi


# Alt Docker dir - if vars set and mounted, then make sure Docker uses it (and not /)
#
if ( \
	[ "${MOUNT_DEV}" ]&& \
	[ "${MOUNT_HDD}" ]&& \
	( grep -q "${MOUNT_DEV}" /proc/mounts )&& \
	( grep -q "${MOUNT_HDD}" /proc/mounts )
)
then
	[ -L /var/lib/docker ]|| sudo ln -s "${MOUNT_HDD}/docker" /var/lib/docker
	sudo sed -i "s|ExecStart=/usr/bin/dockerd -H fd://|ExecStart=/usr/bin/dockerd -g ${MOUNT_HDD}/docker -H fd://|" /lib/systemd/system/docker.service
	( ! which systemctl )|| sudo systemctl daemon-reload
fi


# Start Docker
#
[ $( pgrep -c docker ) -gt 0 ]|| \
	sudo service docker start


# Get Ethernet device name (filtered and keeping only one result)
#
ETHER_DEV="$( ifconfig | grep 'encap:Ethernet' | grep -v 'docker\|veth' | awk '{print $1}' )"
set -- "${ETHER_DEV}"
ETHER_DEV="${1}"


# Static IP - if vars set, Eth dev ID'd and not already is use
#
if ! (
	[ -z "${ETHER_DEV}" ]
	[ -z "${IP_STATIC}" ]|| \
	[ "$( hostname -I | grep ${IP_STATIC} )" ]
)
then
	sudo ip addr add "${IP_STATIC}" dev "${ETHER_DEV}"
fi
