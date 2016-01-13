#!/bin/sh
#
# stop Oscar access to database
sudo /etc/init.d/tomcat6 stop
#
DATE=`date +%Y%m%d_%H%M%S`
echo "Enter mysql admin password..."
mysqldump -u root -p --databases oscar_12_1 > /tmp/oscar_12_1-$DATE.sql
#
# restart Oscar
sudo /etc/init.d/tomcat6 start
