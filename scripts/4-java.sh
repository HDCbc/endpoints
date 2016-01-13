#!/bin/bash
#
# Exit on errors or unintialized variables
#
set -e -x -o nounset


# Silently add PPA
#
sudo add-apt-repository -y ppa:webupd8team/java


# Suppress Oracle's license prompt
#
echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections
echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections
#
# http://stackoverflow.com/questions/19275856/auto-yes-to-the-license-agreement-on-sudo-apt-get-y-install-oracle-java7-instal


# Update package and install java
#
sudo apt-get update
sudo apt-get install oracle-java6-installer -y


# Enable (/set symbolic links) to Java
#
sudo update-alternatives --config java
sudo update-alternatives --config javac
sudo update-alternatives --config javaws


# Sets JAVA_HOME and adds it to /etc/environment and ~/.bashrc
#
export JAVA_HOME="/usr/lib/jvm/java-6-oracle"

if ! (grep --quiet "JAVA_HOME=" /etc/environment)
then
  sudo bash -c 'echo JAVA_HOME=/usr/lib/jvm/java-6-oracle >> /etc/environment'
fi

if ! (grep --quiet "JAVA_HOME=" $HOME/.bashrc)
then
  echo JAVA_HOME="/usr/lib/jvm/java-6-oracle" | tee -a $HOME/.bashrc
fi
source ~/.bashrc



