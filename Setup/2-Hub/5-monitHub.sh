#!/bin/bash
#
# Exit on errors or unintialized variables
#
set -e -x -o nounset


# Create ~/bin folder for start/stop scripts
#
if [ ! -d $HOME/bin ]
then
  mkdir $HOME/bin
fi


# Create start-hub.sh
#
cat > $HOME/bin/start-hub.sh << 'EOF1'
  #!/bin/bash
  #
  export HOME=/home/pdcadmin
  source $HOME/.bash_profile
  source $HOME/.bashrc


  # Stop Query Composer if it's running (or has a stale pid)
  #
  cd $HOME/hub
  if [ -f $HOME/hub/tmp/pids/delayed_job.pid ];
  then
    bundle exec $HOME/hub/script/delayed_job stop
    rm $HOME/hub/tmp/pids/delayed_job.pid
  fi


  # Start Query Composer
  #
  bundle exec $HOME/hub/script/delayed_job start


  # Start gateway, stopping old pid or stale processes
  #
  if [ -f $HOME/hub/tmp/pids/server.pid ];
  then
    kill `cat $HOME/hub/tmp/pids/server.pid`
    if [ -f $HOME/hub/tmp/pids/server.pid ];
    then
      kill -9 `cat $HOME/hub/tmp/pids/server.pid`
    fi
    rm $HOME/hub/tmp/pids/server.pid
  fi

  bundle exec rails server -p 3002 -d

EOF1


# Create bin/stop-hub.sh
#
cat > $HOME/bin/stop-hub.sh << 'EOF2'
  #!/bin/bash
  #
  export HOME=/home/pdcadmin
  source $HOME/.bash_profile
  source $HOME/.bashrc

  # Stop any delayed jobs
  #
  cd $HOME/hub/

  if [ -f $HOME/hub/tmp/pids/delayed_job.pid ];
  then
    bundle exec $HOME/hub/script/delayed_job stop

    # pid file should be gone but recheck
    #
    if [ -f $HOME/hub/tmp/pids/delayed_job.pid ];
    then
      rm $HOME/hub/tmp/pids/delayed_job.pid
    fi
  fi


  # If gateway is running, stop it.
  #
  if [ -f $HOME/hub/tmp/pids/server.pid ];
  then
    kill `cat $HOME/hub/tmp/pids/server.pid`

    if [ -f $HOME/hub/tmp/pids/server.pid ];
    then
      kill -9 `cat $HOME/hub/tmp/pids/server.pid`
    fi

    rm $HOME/hub/tmp/pids/server.pid
  fi

EOF2


# Make the contents of $Home/bin executable (start-hub.sh and stop-hub.sh)
#
chmod a+x $HOME/bin/*.sh


# Configure monit to enable command-line monit tools
#
sudo bash -c "cat >> /etc/monit/monitrc" << 'EOF0'

# Required for monit tools to work
#
set httpd port 2812 and
use address localhost
allow localhost

EOF0


## Configure monit to control the query-composer
#
sudo bash -c "cat > /etc/monit/conf.d/query-composer" <<'EOF1'
# Monitor gateway, allow starting/stopping of query-composer
#
check process query-composer with pidfile /home/pdcadmin/hub/tmp/pids/server.pid
  start program = "/bin/bash -c '/home/pdcadmin/bin/start-hub.sh'" as uid "pdcadmin" and gid "pdcadmin"
  stop program = "/bin/bash -c '/home/pdcadmin/bin/stop-hub.sh'" as uid "pdcadmin" and gid "pdcadmin"
  if 100 restarts within 100 cycles then timeout

EOF1


# Start query-composer
#
/home/pdcadmin/bin/start-hub.sh


# Restart monit and check status
#
sudo /etc/init.d/monit reload
sudo monit status verbose
