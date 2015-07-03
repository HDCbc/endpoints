#!/bin/bash
#
# Exit on errors or unintialized variables
#
set -e -x -o nounset


# Make sure Query Gateway is running
#
sudo monit start query-gateway


# Open Mongo and clear out the query_gateway_development db
#
mongo
> show dbs # expecting ~0.078 GB with default install
> use query_gateway_development # switch to db
> db.records.count() # 500
> db.records.remove({}) # Like a wildcard, removes all records
> db.records.count() # 0
> exit


# Import Oscar test data
#
./mysql_restore.sh oscar_12_1 IT15-121-oct16-09-29-2014.sql
#
# It doesn't hurt to use another terminal to watch catalina.out
# tail -f /var/lib/tomcat6/logs/catalina.out
# Look for "E2ESchedulerJob:202] 10 records processed"


# Optionalally, verify query_gateway_development has 10 records
#
mongo
> show dbs # expecting ~0.078 GB with default install
> use query_gateway_development # switch to db
> db.records.count() # 10
> exit


# Copy Oscar Scripts to ~/bin/
#
cp *.sh ~/bin/