#!/bin/bash
#
# Wave 1 to wave 2 upgrade script
#
set -o nounset


# Decrypt /encrypted/ and source the endpoint.env
[ -d /encrypted/docker/ ]|| \
	sudo /usr/bin/encfs --public /.encrypted /encrypted


# Create docker dir
sudo mkdir -p /encrypted/docker/
sudo chown -R pdcadmin:pdcadmin /encrypted/docker/


# Set import dir
echo
cat /etc/passwd | grep encrypted
echo
echo "Enter OSP account name or leave blank for none"
read OSP_ACCOUNT
if [ -z "${OSP_ACCOUNT}" ]
then
	sudo useradd -m -d /encrypted/docker/import -c "OSP Export Account" -s /bin/bash exporter
else
	{
		sudo usermod -m -d /encrypted/docker/import ${OSP_ACCOUNT}
		sudo mkdir -p /encrypted/docker/import/.ssh/
		sudo chown -R ${OSP_ACCOUNT}:${OSP_ACCOUNT} /encrypted/docker/import
		sudo chmod 700 /encrypted/docker/import
		sudo chmod -R 600 /encrypted/docker/import/.ssh/
	}
fi


# Setup scripts
cd /encrypted/docker/
[ -s endpoint.env ]|| \
	wget https://raw.githubusercontent.com/PDCbc/ep2.0-test/master/endpoint.env-sample -O endpoint.env
[ -s endpoint.sh ]|| \
	wget https://raw.githubusercontent.com/PDCbc/ep2.0-test/master/endpoint.sh
chmod +x endpoint.sh


# Echo config details
echo
cat /home/pdcadmin/endpoint/query-gateway/providers.txt | grep -v 91604 | grep -v 999998 | grep -v cpsid
echo
echo "Copy any relevant CPSIDs for setting the config file"
echo
echo "Press Enter to continue or Ctrl-C to cancel"
echo
read -s CONT
sudo nano endpoint.env


# Reconfigure monit
sudo rm /etc/monit/query-gateway || true
sudo rm /etc/monit/autossh_endpoint || true


# Stop previous services and reload
sudo monit stop query-gateway || true
sudo monit stop autossh_endpoint || true
sudo monit reload


# Kill services using port 3001
toKill=$(ps aux | grep -v grep | grep 3001 | awk '{ print $2 }')
for k in $toKill
do
	sudo kill -9 $k
done


# Update system, cleanup and update-grub
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get dist-upgrade -y
sudo apt-get autoremove -y
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
sudo update-grub


# Start Docker scripts
cd /encrypted/docker
./endpoint.sh deploy
