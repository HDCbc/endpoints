#!/bin/bash
#
# Exit on errors or unintialized variables
#
set -e -x -o nounset


# Update OS
#
sudo apt-get update
sudo apt-get dist-upgrade -y


# Create variable list of packages to install
#
toInstall="
  git
  ntp
  curl
  python-software-properties
  libxslt1-dev
  libxml2-dev
  lynx-cur
  tshark
  screen
  autossh
  monit
  encfs
"
#
# git included in case scripts are copied by another method (scp, flash drive, etc.)


# Install applications from variable $toInstall
#
for app in $toInstall
do
  sudo apt-get install -y $app || echo $app install failed >> ERRORS.txt
done


# Create ~/.bash_profile and have it source ~/.profile
#
if ! (grep --quiet ". ~/.profile" ~/.bash_profile)
then
  echo '. ~/.profile' >> ~/.bash_profile
fi


# Speed up SSH login by adding to sshd_config (checks if already added)
#
if(! grep --quiet "UseDNS no" /etc/ssh/sshd_config)
then
  echo '' | sudo tee -a /etc/ssh/sshd_config
  echo '# Speed up ssh login connections to server' | sudo tee -a /etc/ssh/sshd_config
  echo 'UseDNS no' | sudo tee -a /etc/ssh/sshd_config
fi


# Disable unattended-upgrade by adding to /etc/apt/apt.conf.d/10periodic (with check)
#
if(! grep --quiet 'APT::Periodic::Unattended-Upgrade "0";' /etc/apt/apt.conf.d/10periodic)
then
  echo 'APT::Periodic::Unattended-Upgrade "0";' | sudo tee -a /etc/apt/apt.conf.d/10periodic
fi