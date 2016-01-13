#!/bin/bash
#
# Exit on errors or unintialized variables
#
set -e -x


# Note: `set -o nounset` cannot be used with RVM, which uses an unbound variable


# If ~/endpoint exists, then remove and recreate it
#
cd $HOME
if [ -d endpoint ]
then
  rm -rf endpoint
fi


# Source
#
. ~/.bash_profile


# Clone Query-Gateway (endpoint) repository into ~/endpoint/query-gateway and install it
#
mkdir -p $HOME/endpoint/
cd $HOME/endpoint/
if ! [ -d query-gateway ]
then
  git clone https://github.com/scoophealth/query-gateway.git
  cd query-gateway
else
  cd query-gateway
  git pull
fi
bundle install
bundle exec rake db:seed
bundle exec rake test
mkdir -p $HOME/endpoint/query-gateway/tmp/pids


# Explain expected warning on call to x-www-browser for headless systems
#
echo -e "\e[0;31m"
echo -e "-- warning expected on call to x-www-browser for headless systems --\e[0m"
echo -e "\e[0m"


# Create tmp/pids directory
#
if [ -d tmp/pids ]
then
  mkdir -p tmp/pids
fi