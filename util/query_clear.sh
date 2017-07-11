#!/bin/bash
#
# Halt on errors or unset variables
#
set -eu


# Clear the queries and results collections, showing initial results
#
echo
sudo docker exec -ti gateway_db mongo query_gateway_development --eval 'db.getCollectionNames()' | grep -v "MongoDB\|connecting"
echo
echo "Queries, records and delayed_backend_mongoid_jobs counts:"
sudo docker exec -ti gateway_db mongo query_gateway_development --eval 'db.queries.count()' | grep -v "MongoDB\|connecting"
sudo docker exec -ti gateway_db mongo query_gateway_development --eval 'db.results.count()' | grep -v "MongoDB\|connecting"
sudo docker exec -ti gateway_db mongo query_gateway_development --eval 'db.delayed_backend_mongoid_jobs.count()' | grep -v "MongoDB\|connecting"
echo "Queries, records and delayed_backend_mongoid_jobs drops:"
sudo docker exec -ti gateway_db mongo query_gateway_development --eval 'db.queries.drop()' | grep -v "MongoDB\|connecting"
sudo docker exec -ti gateway_db mongo query_gateway_development --eval 'db.results.drop()' | grep -v "MongoDB\|connecting"
sudo docker exec -ti gateway_db mongo query_gateway_development --eval 'db.delayed_backend_mongoid_jobs.drop()' | grep -v "MongoDB\|connecting"


# Open Lynx to verify running and no queries
#
lynx localhost:3001 --accept-all-cookies


# Summarize
#
echo "Queries, records and delayed_backend_mongoid_jobs counts:"
sudo docker exec -ti gateway_db mongo query_gateway_development --eval 'db.queries.count()' | grep -v "MongoDB\|connecting"
sudo docker exec -ti gateway_db mongo query_gateway_development --eval 'db.results.count()' | grep -v "MongoDB\|connecting"
sudo docker exec -ti gateway_db mongo query_gateway_development --eval 'db.delayed_backend_mongoid_jobs.count()' | grep -v "MongoDB\|connecting"
echo
sudo docker exec -ti gateway_db mongo query_gateway_development --eval 'db.getCollectionNames()' | grep -v "MongoDB\|connecting"
echo
