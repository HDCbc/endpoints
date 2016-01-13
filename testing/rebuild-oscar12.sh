#!/bin/bash
#
set -e # Exit on errors
#
# In case we want to run this from monit set up environment correctly
#HOME=/home/scoopadmin
source $HOME/.bashrc
if [ -z "$CATALINA_BASE" ]
then
  echo "Environment variable CATALINA_BASE is not set.  Exiting..."
  exit
fi
if [ -z "$CATALINA_HOME" ]
then
  echo "Environment variable CATALINA_HOME is not set.  Exiting..."
  exit
fi
#
# Patch to catalina-tasks.xml
# (See https://issues.apache.org/bugzilla/show_bug.cgi?id=56560)
if ! grep --quiet "tomcat-coyote.jar" $CATALINA_HOME/bin/catalina-tasks.xml
then
  sudo sed -i '/<fileset file="${catalina.home}\/lib\/servlet-api.jar"\/>/a<fileset file="${catalina.home}\/lib\/tomcat-coyote.jar"\/>' $CATALINA_HOME/bin/catalina-tasks.xml
fi
#
if [ ! -d $HOME/emr/oscar ]
then
  echo "No Oscar source found.  Exiting..."
  exit
fi
# Stop tomcat while redeploying Oscar
sudo /etc/init.d/tomcat6 stop
# Update to latest scoop-deploy build
cd $HOME/emr/oscar
git fetch origin
git checkout scoop-deploy
git reset --hard origin/scoop-deploy
# Tomcat versions 6.0.38 and 6.0.39 renamed the validateXml attribute
# to validateTld causing build errors like this:
# [ERROR] BUILD ERROR
# [INFO]
# ------------------------------------------------------------------------
# [INFO] An Ant BuildException has occured: The following error occurred
# while executing this line:
# jspc.xml:49: jasper doesn't support the "validateXml" attribute
# around Ant part ...<ant antfile="jspc.xml" target="jspc"/>... @ 5:42 in
# target/antrun/build-main.xml
sed -i 's/validateXml="false"//' jspc.xml
# Note Ubuntu 14.04 deploys Tomcat 6.0.39 by default as of Oct 2014
# Build Oscar from source
export CATALINA_HOME
mvn -Dmaven.test.skip=true clean verify
# Clean out old oscar deployment
sudo rm -rf $CATALINA_BASE/webapps/oscar12
sudo rm $CATALINA_BASE/webapps/oscar12.war
# Copy over new oscar war file
sudo cp ./target/*.war $CATALINA_BASE/webapps/oscar12.war
# build oscar_documents from source
if [ ! -d $HOME/emr/oscar_documents ]
then
  echo "No Oscar_documents found."
else
  cd $HOME/emr/oscar_documents
  git pull
  mvn -Dmaven.test.skip=true clean package
  sudo cp ./target/*.war $CATALINA_BASE/webapps/OscarDocument.war
fi
# Restart Tomcat
sudo /etc/init.d/tomcat6 start
