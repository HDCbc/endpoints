#!/bin/bash
#
# Halt on errors or unset variables
#
set -eu


# Get source file, following symlinks, and store the parent directory
#
SOURCE="${BASH_SOURCE[0]}"
[ ! -h ${SOURCE} ]|| \
	SOURCE="$( readlink ${SOURCE} )"
PARENT_DIR="$( cd -P $( dirname ${SOURCE} )/.. && pwd )"


# Source config, from the parent directory
#
. ${PARENT_DIR}/config.env


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
fi


# Start Docker
#
[ $( pgrep -c docker ) -gt 0 ]|| \
	sudo service docker start


# Allow local server through firwall, if provided
#
[ -z ${DATA_FROM} ]|| \
	sudo ufw allow from ${DATA_FROM}


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
