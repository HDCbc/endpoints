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


# Mount Dock HDD, if provided
#
[ -z ${MOUNT_DEV} ]|| \
	( grep -q ${MOUNT_DEV} /proc/mounts )|| \
	sudo mount ${MOUNT_DEV} ${ENCRYPTED}


# Decrypt private data folders
#
[ -s /hdc/data/mongo/WiredTiger ]|| \
	sudo /usr/bin/encfs --public ${ENCRYPTED} ${VOLS_DATA}


# Start Docker
#
[ $( pgrep -c docker ) -gt 0 ]|| \
	sudo service docker start


# Allow local server through firwall, if provided
#
[ -z ${DATA_FROM} ]|| \
	sudo ufw allow from ${DATA_FROM}


# Add static IP, if provided and not already in use
#
if [ ! -z ${IP_STATIC} ]&&[ ! "$( hostname -I | grep ${IP_STATIC} )" ]
then
	# Grab Ethernet ports, filter (virtua, docker) and keep only one result
	#
	ETHERNAME="$( ifconfig | grep 'Ethernet' | grep -v 'docker\|veth' | awk '{print $1}' )"
	set -- ${ETHERNAME}
	ETHERNAME=${1}

	# Add IP to $ETHERNAME, if one was found
	#
	[ ! "${ETHERNAME}" ]|| \
		sudo ip addr add ${IP_STATIC} dev ${ETHERNAME}
fi
