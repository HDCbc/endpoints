devops
======

Temporary git repo for PDC endpoint and hub setup scripts in development.



## Assumptions

Server hardware:

* Lenovo M92p SFF i7-3770, 8GB RAM, 1TB HD, Win 7 Pro (1st gen deployment)
* Lenovo M93p SFF i7-4770, 8GB RAM, 1TB HD, Win 7 Pro (2nd gen deployment)


Install media:

* [Ubuntu Server 14.04 (LTS)](http://www.ubuntu.com/download/server/thank-you?country=CA&version=14.04.1&architecture=amd64), bootable on a flash drive


## Prerequisites

* A hub must be setup before the endpoints that connect to it
* A three digit (###) Gateway ID for endpoints


## Preliminaries

* Load BIOS by pressing F1 and set the internal hard drive as the default boot device
* Load boot selector by pressing F12 and select the Ubuntu media


## OS Build and Create pdcadmin

Install Ubuntu with defaults, possible exceptions:

* Country: Canada
* Primary network interface: em1 (Ethernet)
* Hostname: pdc-### (### = gatewayID, different convention for hubs)
* Full name: PDC Admin
* Username: pdcadmin
* Encrypt home: No
* Partitioning: *-- see below --*
* Manage upgrades: No automatic updates
* Software selection: OpenSSH server


Partitioning:

* Guided - resize ... and use freed space
* Set existing (Windows) partition to 100 GB
  * write changes to disk as prompted

Note: Ubuntu uses 8.5 GB swap and the remaining 876.4 GB as / (root) on ext4


Reboot and login as pdcadmin


Set root password:

* While SSH'd become root with `sudo su - root`
* Change root's password with `passwd`
* This provides us with a second account in case the regular admin is inaccessible


## Update System

Log in as pdcadmin:

* `ssh pdcadmin@<IP_Address>` and provide credentials


Verify that bash shell is being used

* `echo $SHELL` expected: `/bin/bash`


Install Updates:

* `sudo apt-get update; sudo apt-get dist-upgrade -y` does everything automatically

Tip: `sudo apt-get update` updates package lists<br>
Tip: `sudo apt-get upgrade` installs new packages (safe, skips packages with changing dependencies)<br>
Tip: `sudo apt-get dist-upgrade` installs all new packages (less safe, includes everything)<br>
Tip: `-y` optional, automatically confirms ("yes") installation


## IP and SSH Access

SSH Preparation:

* Get the server's IP using `ifconfig em1` or just `ifconfig` for all network adapters
* Keep track of this IP, because it will be required later

Note: The Ethernet port is frequently called eth# instead of em#


SSH Access:

* From another machine's terminal connect with `ssh <admin>@<IPAddress>`


Disconnect the mouse, keyboard and monitor, because our server is now SSH accessible!


## Packages and Applications

Install Git:

* `sudo apt-get install git -y`

Tip: search for packages with `apt-cache search <package>`<br>
Tip: install multiple packages with `sudo apt-get install <p1> <p2> ... <pn> -y`


Clone Install Scripts to the $HOME Directory:

* `cd $HOME`
* `git clone https://github.com/PhysiciansDataCollaborative/endpoint-deployments.git`
* `cd endpoint-deployments`

Note: this repository may become private


## Endpoint Configuration

Run Endpoint Setup:

* `cd devops`
* `cd Setup`
* `./0-endpoint.sh`
* Enter passwords and respond to prompts as required

Tip: Identify files in the current directory with `./`


Scripts Run by 0-endpoint.sh:

* ./1-Common/1-base.sh
* ./1-Common/2-ruby.sh
* ./1-Common/3-mongodb.sh
* ./2-Endpoint/4-java.sh
* ./2-Endpoint/5-queryGateway.sh
* ./2-Endpoint/6-monitEndpoint.sh
* ./2-Endpoint/7-oscar12.sh
* ./2-Endpoint/8-tunnelEndpoint.sh
* ./2-Endpoint/9-security.sh

Note: All scripts are precarious and might be best used as guidelines


Add an Endpoint to a Hub:

* Login to https://hub_url_here:3002 using an hQuery acccount (see Hub, Creating hQuery Users)
* Dashboard > ADD GATEWAY
  * Name: pdc-### (GatewayID)
  * URL: http://localhost:40000 + endpoint id (for example, endpoing 005 would be 40005)
  * CREATE ENDPOINT

Tip: Click the Queries tab, click a query title and run a few tests on the new endpoint

Testing Oscar

* Please see the Oscar 12 testing guide, which will be linked here once it's written



## Hub Configuration

Run Hub Setup:

* `cd devops`
* `cd Setup`
* `./0-hub.sh`
* Enter passwords and respond to prompts as required

Tip: Identify files in the current directory with `./`


Scripts Run by 0-hub.sh:

* ./1-Common/1-base.sh
* ./1-Common/2-ruby.sh
* ./1-Common/3-mongodb.sh
* ./2-Hub/4-queryComposer.sh
* ./2-Hub/5-monitHub.sh
* ./2-Hub/6-autossh.sh

Note: All scripts are precarious and might be best used as guidelines


Creating hQuery Users:

* Visit `https://<IP_Address>:3002`
* There is no SSL certificate, so expect warnings
* Click "Sign Up" and get sent to `https://<IP_Address>:3002/users/sign_up`
* Fill out the new user form, agree to the terms and click "create"
* Take note of the `<User_Name>`
* The next screen nonsensically reads "You need to sign in or sign up before continuing."

Tip: Browse from the server using only text!  `lynx https://<IP_Address>:3002`


Accepting Users and Granting Rights:

* Navigate to the hub's hQuery directory `cd ~/hub/`
* Grant admin with `bundle exec rake hquery:users:grant_admin USER_ID=<User_Name>`
* Grant regular access with `bundle exec rake hquery:users:approve USER_ID=<User_Name>`

Tip: `-bash: syntax error` comes up when `<` and/or `>` are not removed


## Script Explanations

For further details, just open up a script and read the comments!


### Common

1-base.sh:

* Installs `ntp curl python-software-properties libxslt1-dev libxml2-dev lynx-cur tshark screen autossh monit encfs`
* Verifies that `git` has been installed (in case scripts weren't copied using git)
* Creates ~/.bash_profile and has it source ~/.profile
* Speed up ssh login connects by appending this to /etc/ssh/sshd_config `UseDNS no`
* Disable any possibility of automatic updates in `/etc/atp/apt.conf.d/10periodic`


2-ruby:

* Installs [Ruby and Rails using RVM (Ruby Version Manager)](http://rvm.io/)


3-mongodb:

* Installs [MongoDB](http://docs.mongodb.org/manual/tutorial/install-mongodb-on-ubuntu/)


### Endpoint

4-java:

* Installs [Java 6](http://www.webupd8.org/2012/11/oracle-sun-java-6-installer-available.html) from a personal packet archive (PPA)


5-queryGateway:

* Installs [Query Gateway](https://github.com/scoophealth/query-gateway.git) and libraries for PDC Health software


6-monitEndpoint:

* Creates ~/bin/start-endpoint.sh and ~/bin/stop-endpoint.sh
* Configures monit port and address settings in `/etc/monit/monitrc`
* Creates monit config file for Query Composer in `/etc/monit/conf.d/query-gateway`


7-oscar12:

* Prompts for MySQL database password
* Installs Oscar 12 with E2E, including many BC specific customizations (very slow!)
* Loads the drugref database by launching lynx browser (takes over an hour)
  * If this fails, try again with `lynx http://localhost:8080/drugref/Update.jsp`


8-tunnelEndpoint:

* Generates and handles keys
* Configures access by Gateway ID
* Configures scripts and reverse SSH
* Enables command line access to monit


9-security:

* Prevents history from saving commands
* Configures ufw (Uncomplicated Firewall)
* Stops Tomcat and MongoDB from starting automatically on reboot
* Moves Tomcat and MongoDB files to an encrypted area
* Configures encrypted area and how it can be accessed
* Reboots


## Troubleshooting

### "bundle not found"

This usually happens on the hub while handling users. Unfortunately the Ruby installer does not always work correctly.  Rerun 2-ruby and reboot.

### "Could not find rake-10.3.2 in any of the sources."

..."Run \`bundle install\` to install missing gems."

This is also a Ruby problem.  From the directory you want to run bundle enter `bundle install`.
