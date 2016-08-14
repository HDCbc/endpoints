#!/bin/bash
#
# Prepare Endpoint deployment


# Halt on errors or uninitialized Variables
#
set -e -o nounset


# Load Config file and Store GATEWAY_ID
#
source ./config.env
if [ -z ${GATEWAY_ID} ]
then
        echo
        echo 'Error: config.env not configured'
        echo
        exit
fi


# Set Remaining Variables
#
SCRIPT_DIR=/usr/local/reverse_ssh/bin


# Store GATEWAY_ID in /etc/environment
#
if(! grep --quiet 'GATEWAY_ID=' /etc/environment )
then
        echo "GATEWAY_ID=${GATEWAY_ID}" | sudo tee -a /etc/environment
fi


# Root SSH Keys
#
if( sudo test ! -e /root/.ssh/id_rsa )
then
        sudo ssh-keygen -b 4096 -t rsa -N "" -C ep${GATEWAY_ID}-$(date +%Y-%m-%d-%T) -f /root/.ssh/id_rsa
        echo
        echo
        echo
fi


# Test SSH Connection as Root
#
sleep 5
echo
echo
if ( sudo ssh -p 2774 142.104.128.120 /app/test/ssh_landing.sh )
then
        echo 'Connection succesful!'
else
        sudo cat /root/.ssh/id_rsa.pub
        echo 'ERROR: unable to connect to 142.104.128.120'
        echo
        echo 'Please verify the ssh public key (above) has been provided to admin@hdcbc.ca.'
        echo
        echo 'Press Enter to continue'
        read -s ENTER_PAUSE
fi
echo


# Docker
#
#wget -qO- https://raw.githubusercontent.com/HDCbc/devops/master/docker/docker_setup.sh | sh


# Install AutoSSH and Monit
#
if( ! which autossh )||( ! which monit )
then
        sudo apt update
        sudo apt install autossh monit -y
fi


# Configure Monit (via monitrc)
#
if( sudo grep "# set httpd port 2812 and" /etc/monit/monitrc )
then
        sudo sed -i \
                -e "/include \/etc\/monit\/conf-enabled\// s/^/#/" \
                -e "/set httpd port 2812 and/s/^#//g" \
                -e "/use address localhost/s/^#//g" \
                -e "/allow localhost/s/^#//g" \
                /etc/monit/monitrc
fi
#
sudo monit reload


# Configure Monit
#
MONIT_COMPOSER=/etc/monit/conf.d/autossh_composer
if ! [ -s ${MONIT_COMPOSER} ]
then
        ( \
        echo ''; \
        echo '# Monitor autossh_composer'; \
        echo '#'; \
        echo 'check process autossh_composer with pidfile /autossh_composer.pid'; \
        echo '    start program = "/bin/bash -c '\''export AUTOSSH_PID=/autossh_composer.pid; /usr/bin/autossh -M0 -p 2774 -N -R '$(expr 44000 + ${GATEWAY_ID})':localhost:22 -i /root/.ssh/id_rsa autossh@142.104.128.120 -o ServerAliveInterval=15 -o StrictHostKeyChecking=no -o ServerAliveCountMax=3 -o Protocol=2 -o ExitOnForwardFailure=yes -v'\''"'; \
        echo '     stop program = "/bin/bash -c '\''kill $( echo /autossh_composer.pid )'\''"'; \
        echo '    if 100 restarts within 100 cycles then timeout'; \
        ) | sudo tee -a ${MONIT_COMPOSER}
fi
sudo chmod 600 ${MONIT_COMPOSER}


# Upgrade System, Update GRUB and Reboot
#
sudo apt update
sudo apt upgrade -y
sudo apt dist-upgrade -y
sudo update-grub
sudo reboot
