#!/bin/bash
#
# Exit on errors or unintialized variables
#
set -e -x -o nounset


# Generate endpoint's public rsa key (as root)
#
sudo su - root -c 'ssh-keygen -t rsa -f /root/.ssh/id_rsa -q -N ""'


# Copy endpoint public key to /tmp/ on the hub
#
sudo scp -p /root/.ssh/id_rsa.pub pdcadmin@pdchub.uvic.ca:/tmp/endpoint_id_rsa.pub


# Append /tmp/endpoint_id_rsa.pub to autossh's authorized keys
#
ssh -t pdcadmin@pdchub.uvic.ca "sudo su - autossh -c 'cat /tmp/endpoint_id_rsa.pub >> /home/autossh/.ssh/authorized_keys'"


# Prompt for a gatewayID
#
echo "Please enter a gatewayID of form ###: "
read gatewayID
echo ""
echo "=> gatewayID: $gatewayID"
echo ""
echo "Please confirm this ID and press ENTER or Ctrl+C to cancel"
read enterToContinue


if [ ! -d /usr/local/reverse_ssh/bin ]
then
  sudo mkdir -p /usr/local/reverse_ssh/bin
fi
sudo bash -c "cat  > /usr/local/reverse_ssh/bin/start_admin_tunnel.sh" <<'EOF1'
#!/bin/bash
REMOTE_ACCESS_PORT=1000000000
LOCAL_PORT_TO_FORWARD=22
export AUTOSSH_PIDFILE=/usr/local/reverse_ssh/autossh_admin.pid
/usr/bin/autossh -M0 -p22 -N -R ${REMOTE_ACCESS_PORT}:localhost:${LOCAL_PORT_TO_FORWARD} autossh@pdchub.uvic.ca -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o Protocol=2 -o ExitOnForwardFailure=yes &
#
EOF1
#
sudo bash -c "sed -i -e s/REMOTE_ACCESS_PORT=1000000000/REMOTE_ACCESS_PORT=`expr 44000 + $gatewayID`/ /usr/local/reverse_ssh/bin/start_admin_tunnel.sh"

sudo bash -c "cat  > /usr/local/reverse_ssh/bin/start_endpoint_tunnel.sh" <<'EOF2'
#!/bin/bash
REMOTE_ACCESS_PORT=1000000000
LOCAL_PORT_TO_FORWARD=3001
export AUTOSSH_PIDFILE=/usr/local/reverse_ssh/autossh_endpoint.pid
/usr/bin/autossh -M0 -p22 -N -R ${REMOTE_ACCESS_PORT}:localhost:${LOCAL_PORT_TO_FORWARD} autossh@pdchub.uvic.ca -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o Protocol=2 -o ExitOnForwardFailure=yes &
#
EOF2
#
sudo bash -c "sed -i -e s/REMOTE_ACCESS_PORT=1000000000/REMOTE_ACCESS_PORT=`expr 40000 + $gatewayID`/ /usr/local/reverse_ssh/bin/start_endpoint_tunnel.sh"
#
sudo bash -c "cat  > /usr/local/reverse_ssh/bin/stop_admin_tunnel.sh" <<'EOF3'
#!/bin/sh
test -e /usr/local/reverse_ssh/autossh_admin.pid && kill `cat /usr/local/reverse_ssh/autossh_admin.pid`
EOF3
#
sudo bash -c "cat  > /usr/local/reverse_ssh/bin/stop_endpoint_tunnel.sh" <<'EOF4'
#!/bin/sh
test -e /usr/local/reverse_ssh/autossh_endpoint.pid && kill `cat /usr/local/reverse_ssh/autossh_endpoint.pid`
EOF4
#
sudo chown -R root:root /usr/local/reverse_ssh
sudo chmod 700 /usr/local/reverse_ssh/bin/*.sh
#
#Setup monit to restart autossh
sudo bash -c "cat > /etc/monit/conf.d/autossh_admin" <<'EOF5'
# Monitor autossh_admin
check process autossh_admin with pidfile /usr/local/reverse_ssh/autossh_admin.pid
    start program = "/usr/local/reverse_ssh/bin/start_admin_tunnel.sh"
    stop program = "/usr/local/reverse_ssh/bin/stop_admin_tunnel.sh"
    if 100 restarts within 100 cycles then timeout
EOF5
#
sudo bash -c "cat > /etc/monit/conf.d/autossh_endpoint" <<'EOF6'
# Monitor autossh_endpoint
check process autossh_endpoint with pidfile /usr/local/reverse_ssh/autossh_endpoint.pid
    start program = "/usr/local/reverse_ssh/bin/start_endpoint_tunnel.sh"
    stop program = "/usr/local/reverse_ssh/bin/stop_endpoint_tunnel.sh"
    if 100 restarts within 100 cycles then timeout
EOF6
#
#
if sudo bash -c 'grep --quiet "^set httpd port 2812" /etc/monit/monitrc'
then
  echo '/etc/monit/monitrc already setup for CLI access'
else
  # don't indent the here document
  sudo bash -c "cat >> /etc/monit/monitrc" << 'EOF7'
#
# needed so that monit command-line tools will work
set httpd port 2812 and
use address localhost
allow localhost
EOF7
fi
#
if sudo test -f "/var/spool/cron/crontabs/root"
then
  if sudo bash -c 'grep --quiet autossh_admin /var/spool/cron/crontabs/root'
  then
    echo 'root cron already set to restart auto_ssh'
  else
    echo 'adding monit start autossh_admin to root crontab'
    sudo crontab -u root -l /root/crontab.root
    # don't indent here document below
    sudo bash -c "cat >> /root/crontab.root" << 'EOF8'
# Run five minutes after hour, every day
# Provides automatic recovery if monit unmonitors autossh_admin
5 * * * *  /usr/bin/monit start autossh_admin >> /var/log/monit-cron.log 2>&1
6 * * * *  /usr/bin/monit start autossh_endpoint >> /var/log/monit-cron.log 2>&1
EOF8
    sudo crontab -u root /root/crontab.root
  fi
else
  echo 'creating root crontab with monit start autossh_admin
  # don't indent here document below
  sudo bash -c "cat > /root/crontab.root" << 'EOF9'
# Run five minutes after hour, every day
# Provides automatic recovery if monit unmonitors autossh_admin
5 * * * *  /usr/bin/monit start autossh_admin >> /var/log/monit-cron.log 2>&1
6 * * * *  /usr/bin/monit start autossh_endpoint >> /var/log/monit-cron.log 2>&1

EOF9
    sudo crontab -u root /root/crontab.root
fi
#
sudo /etc/init.d/monit restart
sudo /usr/bin/monit start autossh_admin
sudo /usr/bin/monit start autossh_endpoint
#
echo
echo "Access endpoint from account on hub as follows:"
echo "ssh -l $USER localhost -p 303[0n] where 0n is the gatewayID"
echo "Note that the password request is for the $USER account"
echo "on the endpoint which can be different from the password of"
echo "the $USER acount on the hub."
