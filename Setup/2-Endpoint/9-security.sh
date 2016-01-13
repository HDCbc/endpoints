#!/bin/bash
#
# Exit on errors or unintialized variables
#
set -e -x -o nounset


# Set ~/.bashrc not to save a command history, then clear the existing history
#
if ! ( grep --quiet "unset HISTFILE" ~/.bashrc )
then
  echo 'unset HISTFILE' >> ~/.bashrc
  echo 'export LESSHISTFILE="-"' >> ~/.bashrc
fi

history -c


# Enable firewall, allowing ssh (port 22), but limiting login attempts to six
#
sudo ufw allow 22
sudo ufw limit 22
sudo ufw --force enable
sudo ufw status verbose


# Prevent Tomcat autostart; start it manually after unlocking the filesystem (encrypted)
#
if [ -f /etc/rc5.d/S92tomcat6 ]
then
  sudo rm /etc/rc?.d/S92tomcat6
fi


# Prevent mongod autostart, since on encrypted filesystem, but leave auto shutdown
#
sudo sed --in-place "s/start on runlevel/#start on runlevel/" /etc/init/mongod.conf


### 5) The query-gateway cannot start until the mongodb database filesystem
# has the encryption password entered manually so unmonitor query-gateway
# before monit is shutdown during system shutdown or reboot.  This string
# subsitution adds a line to unmonitor query-gateway in the stop) section
# of /etc/init.d/monit.  This is needed because the monitoring state is
# persistent across Monit restarts

# Set monit not to watch 
#
sudo sed --in-place "/stop)/{G;s/$/    \/usr\/bin\/monit unmonitor query-gateway/;}" /etc/init.d/monit


### 6) Move mongodb database to an encrypted filesystem.
# First quit monitoring query-gateway, stop monit, then gateway software
# and mongodb:
#
if [ ! -d /encrypted ]
then
  sudo monit unmonitor query-gateway
#  sudo /etc/init.d/monit stop
  $HOME/bin/stop-endpoint.sh

  if ( ps -e | grep mongo )
  then
    sudo service mongod stop
  fi

  # Move mongodb to encrypted filesystem
  #
  echo "You need to set up passphrase now"
  sudo encfs --public /.encrypted /encrypted
  sudo rsync -av /var/lib/mongodb /encrypted
  sudo chmod a+rx /encrypted
  sudo chmod a+rx /.encrypted

  if [ ! -d /encrypted/mongodb ]
  then
    echo "Error occurred moving mongodb to encrypted filesystem"
    exit
  fi

  sudo sed --in-place "s/\/var\/lib\/mongodb/\/encrypted\/mongodb/" /etc/mongod.conf
  sudo /etc/init.d/monit start
  cd ~/endpoint/query-gateway
  sudo mv log /encrypted/endpoint-log
  sudo ln -s /encrypted/endpoint-log ./log
  echo "sudo /usr/bin/encfs --public /.encrypted /encrypted && sudo initctl start mongod && sudo monit start query-gateway" > $HOME/start-encfs-mongo-endpoint
  cd $HOME
  chmod a+x ./start-encfs-mongo-endpoint
fi


### 6) Move the oscar properties file to the encrypted filesystem
#
export CATALINA_HOME=/usr/share/tomcat6 #
if [ -f $CATALINA_HOME/oscar12.properties ]
then
  if [ ! -h $CATALINA_HOME/oscar12.properties ]
  then
    cd $CATALINA_HOME
    sudo mkdir /encrypted/oscar
    sudo mv oscar12.properties /encrypted/oscar
    sudo ln -s /encrypted/oscar/oscar12.properties ./oscar12.properties
    sudo chown root:tomcat6 /encrypted/oscar/oscar12.properties
    sudo chmod o-rwx /encrypted/oscar/oscar12.properties
  fi
fi


# Reboot and verify that everything comes back properly
#
sudo reboot now
