#!/bin/bash
#
# Exit on errors or unintialized variables
#
set -e -x -o nounset


# Store full path to sed scripts
#
script_dir="$(dirname $(readlink -f ${BASH_SOURCE[0]}))"
sed_script="oscar12-sedScripts.sed"
sed_launch=$script_dir/$sed_script


# Create variable list of packages to install
#
toInstall="
mysql-server
libmysql-java
tomcat6
maven
"


# Install applications from variable $toInstall
#
for app in $toInstall
do
sudo apt-get install -y $app || echo $app install failed >> ERRORS.txt
done


# Set environment variables, add them to /etc/environment and ~/.bashrc
#
export CATALINA_HOME="/usr/share/tomcat6"
export CATALINA_BASE="/var/lib/tomcat6"
export ANT_HOME="usr/share/ant"
export JAVA_HOME="/usr/lib/jvm/java-6-oracle"

if ! (grep --quiet "CATALINA_BASE=" /etc/environment)
then
echo CATALINA_HOME=$CATALINA_HOME | sudo tee -a /etc/environment
echo CATALINA_BASE=$CATALINA_BASE | sudo tee -a /etc/environment
echo ANT_HOME=$ANT_HOME | sudo tee -a /etc/environment
fi

if ! (grep --quiet "CATALINA_BASE=" $HOME/.bashrc)
then
echo CATALINA_HOME=$CATALINA_HOME | sudo tee -a $HOME/.bashrc
echo CATALINA_BASE=$CATALINA_BASE | sudo tee -a $HOME/.bashrc
echo ANT_HOME=$ANT_HOME | sudo tee -a $HOME/.bashrc
echo export JAVA_HOME CATALINA_HOME CATALINA_BASE ANT_HOME | sudo tee -a $HOME/.bashrc
fi
source ~/.bashrc


# Restart Tomcat6 after pointing to $JAVA_HOME
#
if ! (grep --quiet "java-6-oracle" /etc/default/tomcat6)
then
echo "" | sudo tee -a /etc/default/tomcat6
echo "# JDK home directory" | sudo tee -a /etc/default/tomcat6
echo JAVA_HOME=$JAVA_HOME | sudo tee -a /etc/default/tomcat6
fi

sudo /etc/init.d/tomcat6 restart


# Git clone Oscar into ~/emr/, checkout scoop-deploy branch
#
if [ ! -d $HOME/emr/oscar ]
then
mkdir -p $HOME/emr/
cd $HOME/emr/
git clone git://github.com/scoophealth/oscar.git
fi

cd $HOME/emr/oscar
git fetch origin
git checkout scoop-deploy
git reset --hard origin/scoop-deploy


# Remove `validateXml="false" from jspc.xml (no effect if run again)
#
sed -i 's/validateXml="false"//' jspc.xml
#
# Attrib renamed `validateTld` in Tomcat 6.0.38, back in 6.0.40, using 6.0.39
# ( http://tomcat.apache.org/tomcat-6.0-doc/changelog.html )


# Change `servlet-api.jar` to `tomcat-coyote.jar` in catalina-tasks.xml
#
if ! (grep --quiet "tomcat-coyote.jar" $CATALINA_HOME/bin/catalina-tasks.xml)
then
# should be easier, but out while troubleshooting errors
#
# sudo sed -i.bk 's/servlet-api.jar/tomcat-coyote.jar/' $CATALINA_HOME/bin/catalina-tasks.xml
sudo sed -i '/<fileset file="${catalina.home}\/lib\/servlet-api.jar"\/>/a<fileset file="${catalina.home}\/lib\/tomcat-coyote.jar"\/>' $CATALINA_HOME/bin/catalina-tasks.xml
fi
#
# (See https://issues.apache.org/bugzilla/show_bug.cgi?id=56560 )


# Helps to avoid missing dependencies with Apache Maven
#
mkdir -p $HOME/.m2
rsync -av $HOME/emr/oscar/local_repo/ $HOME/.m2/repository/


# Build Oscar from source using Maven
#
cd $HOME/emr/oscar/
mvn -Dmaven.test.skip=true clean verify


# Copy Web ARchive to Tomcat webapps folder
#
sudo cp ./target/oscar-SNAPSHOT.war $CATALINA_BASE/webapps/oscar12.war


# Git clone and build oscar_documents from source
#
cd $HOME/emr
if [ ! -d ./oscar_documents ]
then
git clone git://oscarmcmaster.git.sourceforge.net/gitroot/oscarmcmaster/oscar_documents
cd ./oscar_documents
else
cd ./oscar_documents
git pull
fi

mvn -Dmaven.test.skip=true clean package


# Copy Web ARchive (.war) to Tomcat webapps folder
#
sudo cp ./target/oscar_documents-SNAPSHOT.war $CATALINA_BASE/webapps/OscarDocument.war


# Prompt for an Oscar password
#
echo -n "Enter Oscar password: "
read oscar_passwd
echo "Create Oscar database with password $oscar_passwd"


# Drop any old databases and start a fresh one
#
mysql -uroot -p$oscar_passwd -e "DROP DATABASE IF EXISTS oscar_12_1;"
cd $HOME/emr/oscar/database/mysql
./createdatabase_bc.sh root $oscar_passwd oscar_12_1


# Make lots of substitutions with sed
#
cd $HOME
if [ ! -f $CATALINA_HOME/oscar12.properties ]
then
sed -f $sed_launch < $HOME/emr/oscar/src/main/resources/oscar_mcmaster.properties > /tmp/oscar12.properties
echo "ModuleNames=E2E" >> /tmp/oscar12.properties
echo "E2E_URL = http://localhost:3001/records/create" >> /tmp/oscar12.properties
echo "E2E_DIFF = off" >> /tmp/oscar12.properties
echo "E2E_DIFF_DAYS = 14" >> /tmp/oscar12.properties
echo "drugref_url=http://localhost:8080/drugref/DrugrefService" >> /tmp/oscar12.properties
sed --in-place "s/db_password=xxxx/db_password=$oscar_passwd/" /tmp/oscar12.properties
sudo cp /tmp/oscar12.properties $CATALINA_HOME/
fi

sudo sed --in-place 's/JAVA_OPTS.*/JAVA_OPTS="-Djava.awt.headless=true -Xmx1024m -Xms1024m -XX:MaxPermSize=512m -server"/' /etc/default/tomcat6


# MySQL server adjustments
#
cd $HOME/emr/oscar/database/mysql
java -cp .:$HOME/emr/oscar/local_repo/mysql/mysql-connector-java/3.0.11/mysql-connector-java-3.0.11.jar importCasemgmt $CATALINA_HOME/oscar12.properties

mysql -uroot -p$oscar_passwd -e 'insert into issue (code,description,role,update_date,sortOrderId) select icd9.icd9, icd9.description, "doctor", now(), '0' from icd9;' oscar_12_1


# Import and update drugref
#
cd $HOME/emr
wget http://drugref2.googlecode.com/files/drugref.war
sudo mv drugref.war $CATALINA_BASE/webapps/drugref.war


# Append to drugref.properties
#
echo "db_user=root" | sudo tee -a $CATALINA_HOME/drugref.properties
echo "db_password=xxxx" | sudo tee -a $CATALINA_HOME/drugref.properties
echo "db_url=jdbc:mysql://127.0.0.1:3306/drugref" | sudo tee -a $CATALINA_HOME/drugref.properties
echo "db_driver=com.mysql.jdbc.Driver" | sudo tee -a $CATALINA_HOME/drugref.properties


# Add password into drugref.properties
#
sudo sed --in-place "s/db_password=xxxx/db_password=$oscar_passwd/" $CATALINA_HOME/drugref.properties

# Drop any old drugref database and start a fresh one
#
mysql -uroot -p$oscar_passwd -e "DROP DATABASE IF EXISTS drugref;"
mysql -uroot -p$oscar_passwd -e "CREATE DATABASE drugref;"


# Restart Tomcat
#
sudo /etc/init.d/tomcat6 restart


# Tell lynx to accept all cookies and launch drugref update
#
lynx -accept_all_cookies http://localhost:8080/drugref/Update.jsp
#
# This can take over an hour, so use the code below to check what its up to
# `tail -f /var/log/tomcat6/catalina.log`
