#!/bin/bash
#
# Exit on errors or unintialized variables
#
set -e -x


# Note: `set -o nounset` cannot be used with RVM, which uses an unbound variable


# If ~/hub exists, then remove and recreate it
#
cd $HOME
if [ -d hub ]
then
  rm -rf hub
fi


# Source
#
source ~/.bash_profile


# Clone Hub (Query Composer) repository into ~/hub and install it
#
git clone https://github.com/scoophealth/query-composer.git
mv query-composer/ hub/
cd hub
bundle install
bundle exec rake db:seed
bundle exec rake test


# Explain expected warning on call to x-www-browser for headless systems
#
echo -e "\e[0;31m"
echo -e "-- warning expected on call to x-www-browser for headless systems --\e[0m"
echo -e "\e[0m"
