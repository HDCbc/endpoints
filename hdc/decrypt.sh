#!/bin/bash
#
# Halt on errors or unset variables
#
set -eu


# Decrypt private data folders
#
[ -s /hdc/data/mongo/WiredTiger ]|| \
	sudo /usr/bin/encfs --public /hdc/.encrypted /hdc/data


# Start Docker
#
[ $( pgrep -c docker ) -gt 0 ]|| \
	sudo service docker start


# Add static IP, if provided in env file
#
. /hdc/endpoint/config.env
IP_STATIC=${IP_STATIC:-"."}
ETHERNAME="$( ifconfig | grep 'enx\|em1' | awk '{print $1}' )"
if [ ! "$( hostname -I | grep ${IP_STATIC} )" ]
then
	sudo ip addr add ${IP_STATIC} dev ${ETHERNAME}
fi
