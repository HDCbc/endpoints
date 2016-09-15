#!/bin/bash
#
# Halt on errors or unset variables
#
set -eu


# Source config
#
. /hdc/endpoint/config.env


# Decrypt private data folders
#
[ -s /hdc/data/mongo/WiredTiger ]|| \
	sudo /usr/bin/encfs --public /hdc/.encrypted /hdc/data


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
