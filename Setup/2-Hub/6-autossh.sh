#!/bin/bash
#
# Exit on errors or unintialized variables
#
set -e -x -o nounset
#
# Omit `-e` on low memory systems, since using adduser with `< /dev/zero` can return an error


# Create autossh account and enable exit on errors
#
sudo adduser --disabled-password autossh < /dev/zero # suppress output: > /dev/null 2>&1


# Prepare autossh for reverse ssh (tunnel) from gateways
#
sudo mkdir /home/autossh/.ssh
sudo touch /home/autossh/.ssh/authorized_keys
sudo chmod -R go-rwx /home/autossh/.ssh
sudo chown -R autossh:autossh /home/autossh/.ssh