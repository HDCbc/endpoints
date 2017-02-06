#!/bin/bash
#
# Halt on errors or unset variables
#
set -eu


# Get Sample10 SQL dump from GitHub and place in import directory
#
echo
sudo su -c "wget -qO- https://github.com/HDCbc/e2e_oscar/blob/master/test/sample10.sql?raw=true > /hdc/data/import/sample10.sql"
echo
