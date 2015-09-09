#!/bin/bash
#
# Exit on errors or unintialized variables
#
set -e -x -o nounset


# Import public key
#
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10


# Add repository to sources
#
echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | sudo tee /etc/apt/sources.list.d/mongodb.list


# Update and install
#
sudo apt-get update
sudo apt-get install mongodb-org -y


# Ref: Install MongoDB on Ubuntu
# http://docs.mongodb.org/manual/tutorial/install-mongodb-on-ubuntu/
