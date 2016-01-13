#!/bin/sh
if [ -z "$2" ]
then
  echo "Usage: $0 dbname dump_file"
  exit
fi
DBNAME=$1
DUMPFILE=$2
echo -n "Enter MySQL user account password: "
read PASSWD
#
# stop Oscar access to database
sudo /etc/init.d/tomcat6 stop
#
mysql -uroot -p$PASSWD -e "drop database $DBNAME;"
mysql -uroot -p$PASSWD -e "create database $DBNAME;"
mysql -uroot -p$PASSWD $DBNAME < $DUMPFILE
#
# restart Oscar
sudo /etc/init.d/tomcat6 start
