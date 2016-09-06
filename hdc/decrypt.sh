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


# Add static IP, if provided and address not yes applied
#
if [ ! -z ${IP_STATIC} ]&&[ ! "$( hostname -I | grep ${IP_STATIC} )" ]
then
	ETHERNAME="$( ifconfig | grep 'enx\|em1' | awk '{print $1}' )"
	sudo ip addr add ${IP_STATIC} dev ${ETHERNAME}
fi
