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


# Create alias to old admin Account
#
if(! grep --quiet 'pdcadmin' /etc/passwd )&&( grep --quiet '/home/hdcadmin' /etc/passwd )
then
        ADMIN_NUMBER=$(id -u hdcadmin)
        echo "pdcadmin:x:${ADMIN_NUMBER}:${ADMIN_NUMBER}:Legacy Admin Account:/home/hdcadmin:/bin/bash" | sudo tee -a /etc/passwd
fi


###
# AutoSSH Composer Connection
###


# Start Script
#
START_COMPOSER=${SCRIPT_DIR}/start_composer.sh
if ! [ -s ${START_COMPOSER} ]
then
        sudo mkdir -p ${SCRIPT_DIR}
	( \
		echo '#!/bin/bash'; \
                echo '#'; \
                echo '# Start AutoSSH Connection to Anchor'; \
                echo ''; \
                echo ''; \
                echo '# Halt on errors or uninitialized Variables'; \
                echo '#'; \
                echo 'set -e -o nounset -x'; \
                echo ''; \
                echo ''; \
		echo '# Configure Variables'; \
                echo '#'; \
                echo 'GATEWAY_ID='${GATEWAY_ID}; \
                echo 'MONIT_NAME=autossh_composer'; \
		echo 'REMOTE_SSH_PORT=$(expr 44000 + ${GATEWAY_ID})'; \
                echo 'LOCAL_SSH_PORT=22'; \
                echo 'SERVER_IP=142.104.128.120'; \
                echo 'SERVER_SSH_PORT=2774'; \
                echo ''; \
                echo ''; \
                echo '# Set Log and Pid Files'; \
                echo '#'; \
                echo 'export AUTOSSH_LOGFILE=/usr/local/reverse_ssh/${MONIT_NAME}.log'; \
                echo 'export AUTOSSH_PIDFILE=/usr/local/reverse_ssh/${MONIT_NAME}.pid'; \
                echo '[ ! -s ${AUTOSSH_PIDFILE} ]|| rm ${AUTOSSH_PIDFILE}'; \
                echo ''; \
                echo ''; \
                echo '# Start Tunnel'; \
                echo '#'; \
                echo '/usr/bin/autossh -M0 -p ${SERVER_SSH_PORT} -N -R ${REMOTE_SSH_PORT}:localhost:${LOCAL_SSH_PORT} autossh@${SERVER_IP} -o ServerAliveInterval=15 -o StrictHostKeyChecking=no -o ServerAliveCountMax=3 -o Protocol=2 -o ExitOnForwardFailure=yes -v'; \
	) | sudo tee ${START_COMPOSER}
        sudo chmod +x ${START_COMPOSER}
fi


# Stop Script
#
STOP_COMPOSER=${SCRIPT_DIR}/stop_composer.sh
if ! [ -s ${STOP_COMPOSER} ]
then
        sudo mkdir -p ${SCRIPT_DIR}
	( \
		echo '#!/bin/bash'; \
                echo '#'; \
                echo '# Stop AutoSSH Connection to Anchor'; \
                echo ''; \
                echo ''; \
		echo '# Configure Variables'; \
		echo '#'; \
                echo 'MONIT_NAME=autossh_composer'; \
                echo 'PIDFILE=/usr/local/reverse_ssh/${MONIT_NAME}.pid'; \
                echo 'PIDKILL=$(cat ${PIDFILE})'; \
                echo ''; \
                echo ''; \
                echo '# Start Tunnel'; \
                echo '#'; \
                echo '[ ! -z ${PIDKILL} ]|| kill ${PIDKILL}'; \
	) | sudo tee ${STOP_COMPOSER}
        sudo chmod +x ${STOP_COMPOSER}
fi


# Configure Monit
#
MONIT_COMPOSER=/etc/monit/conf.d/autossh_composer
if ! [ -s ${MONIT_COMPOSER} ]
then
        ( \
        echo ''; \
        echo '# Monitor autossh_composer'; \
        echo '#'; \
        echo 'check process autossh_composer with pidfile /usr/local/reverse_ssh/autossh_composer.pid'; \
        echo '    start program = "/usr/local/reverse_ssh/bin/start_composer.sh"'; \
        echo '    stop program = "/usr/local/reverse_ssh/bin/stop_composer.sh"'; \
        echo '    if 100 restarts within 100 cycles then timeout'; \
        ) | sudo tee -a ${MONIT_COMPOSER}
fi


##
# AutoSSH Anchor Connection
###


# Start Script
#
START_ANCHOR=${SCRIPT_DIR}/start_anchor.sh
if ! [ -s ${START_ANCHOR} ]
then
        sudo mkdir -p ${SCRIPT_DIR}
	( \
		echo '#!/bin/bash'; \
                echo '#'; \
                echo '# Start AutoSSH Connection to Anchor'; \
                echo ''; \
                echo ''; \
                echo '# Halt on errors or uninitialized Variables'; \
                echo '#'; \
                echo 'set -e -o nounset'; \
                echo ''; \
                echo ''; \
		echo '# Configure Variables'; \
                echo '#'; \
                echo 'GATEWAY_ID='${GATEWAY_ID}; \
                echo 'MONIT_NAME=autossh_composer'; \
		echo 'REMOTE_SSH_PORT=$(expr 44000 + ${GATEWAY_ID})'; \
                echo 'LOCAL_SSH_PORT=22'; \
                echo 'SERVER_IP=149.56.154.244'; \
                echo 'SERVER_SSH_PORT=23646'; \
                echo ''; \
                echo ''; \
                echo '# Set Log and Pid Files'; \
                echo '#'; \
                echo 'export AUTOSSH_LOGFILE=/usr/local/reverse_ssh/${MONIT_NAME}.log'; \
                echo 'export AUTOSSH_PIDFILE=/usr/local/reverse_ssh/${MONIT_NAME}.pid'; \
                echo '[ ! -s ${AUTOSSH_PIDFILE} ]|| rm ${AUTOSSH_PIDFILE}'; \
                echo ''; \
                echo ''; \
                echo '# Start Tunnel'; \
                echo '#'; \
                echo '/usr/bin/autossh -M0 -p ${SERVER_SSH_PORT} -N -R ${REMOTE_SSH_PORT}:localhost:${LOCAL_SSH_PORT} autossh@${SERVER_IP} -o ServerAliveInterval=15 -o StrictHostKeyChecking=no -o ServerAliveCountMax=3 -o Protocol=2 -o ExitOnForwardFailure=yes'; \
	) | sudo tee ${START_ANCHOR}
        sudo chmod +x ${START_ANCHOR}
fi


# Stop Script
#
STOP_ANCHOR=${SCRIPT_DIR}/stop_anchor.sh
if ! [ -s ${STOP_ANCHOR} ]
then
        sudo mkdir -p ${SCRIPT_DIR}
	( \
		echo '#!/bin/bash'; \
                echo '#'; \
                echo '# Stop AutoSSH Connection to Anchor'; \
                echo ''; \
                echo ''; \
		echo '# Configure Variables'; \
		echo '#'; \
                echo 'MONIT_NAME=autossh_composer'; \
                echo 'PIDFILE=/usr/local/reverse_ssh/${MONIT_NAME}.pid'; \
                echo 'PIDKILL=$(cat ${PIDFILE})'; \
                echo ''; \
                echo ''; \
                echo '# Start Tunnel'; \
                echo '#'; \
                echo '[ ! -z ${PIDKILL} ]|| kill ${PIDKILL}'; \
	) | sudo tee ${STOP_ANCHOR}
        sudo chmod +x ${STOP_ANCHOR}
fi


# Configure Monit
#
MONIT_ANCHOR=/etc/monit/conf.d/autossh_anchor
if ! [ -s ${MONIT_ANCHOR} ]
then
        ( \
        echo ''; \
        echo '# Monitor autossh_anchor'; \
        echo '#'; \
        echo 'check process autossh_anchor with pidfile /usr/local/reverse_ssh/autossh_anchor.pid'; \
        echo '    start program = "/usr/local/reverse_ssh/bin/start_anchor.sh"'; \
        echo '    stop program = "/usr/local/reverse_ssh/bin/stop_anchor.sh"'; \
        echo '    if 100 restarts within 100 cycles then timeout'; \
        ) | sudo tee -a ${MONIT_ANCHOR}
fi
