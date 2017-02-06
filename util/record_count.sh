#!/bin/bash
#
# Halt on errors or unset variables
#
set -eu


# Count records in Gateway Db
#
echo
sudo docker exec -ti gateway_db mongo query_gateway_development --eval 'db.records.count()'
echo
