#!/bin/bash
#
# Exit on errors or unintialized variables
#
set -e -o nounset


# Create variable of paths/scripts in ./Common and ./Endpoint directories
# Form: ./dir/0-file.sh ./dir/1-file.sh ...
#
toRun=`ls ./1-Common/*.sh`" "`ls ./2-Endpoint/*.sh`


# Create (overwriting) an install log
#
echo "$0 ran on" $(date) > $HOME/install.log


# Run scipts from $toRun, making sure to return to the script directory
#
for script in $toRun
do
  if $script
  then
    echo "  completed: "$script >> $HOME/install.log
  else
    echo "  failed on: "$script >> $HOME/install.log
    break
  fi
done


# Log success
#
echo "$0.sh completed" >> $HOME/install.log


# Echo log and monit status, coloured red
#
echo -e "\e[0;31m"
cat ~/install.log
echo -e "\e[0m"