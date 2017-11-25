#!/bin/sh
#
# Halt on errors or unassigned variables
#
set -eu


# Import if SQL files are present
#
SQL_CHECK=$( sudo find /hdc/data/import/ -maxdepth 1 -name "*.sql" -o -name "*.xz" -o -name "*.tgz" )
if [ ${#SQL_CHECK[@]} -gt 0 ]
then
        cd /hdc/endpoint
        make import
fi


# Log
#
echo $( date +%Y-%m-%d-%T ) ${SQL_CHECK} | sudo tee -a /hdc/endpoint/import.log
