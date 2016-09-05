#!/bin/bash
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
[ $( hostname -I )| grep ${IP_STATIC} ]|| \
	sudo ip addr add ${IP_STATIC} dev em1
