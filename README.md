# HDC Endpoints
## Self- and HDC-Managed Deployment Options
======

Temporary git repo for PDC endpoint and hub setup scripts in development.



## Assumptions

Server hardware:

* Lenovo M92p SFF - i7-3770, 8GB RAM, 1TB HD (1st gen deployment)
* Lenovo M93p SFF - i7-4770, 8GB RAM, 1TB HD (2nd gen deployment)
* HP Pavilion Mini - Pentium 3558U, 4GB RAM, 500GB HD (3nd gen deployment)
* InFocus Kangaroo Pro - Atom x5-Z8500, 2GB RAM, 32GB HD (4th gen deployment)


Install media:

* [Ubuntu Server 16.04 (LTS)](http://www.ubuntu.com/download/server/thank-you?version=16.04.1&architecture=amd64), bootable on a flash drive


## 0. Prerequisites

* A Composer/Hub must be setup for Endpoints to connect to it
* A four digit (####) Gateway ID for Endpoints


## 1. Install Operation System

Boot from USB media

* During boot press F10 to select Ubuntu Server on USB drive


Install Ubuntu with defaults, possible exceptions:

* Country: Canada
* Keyboard: English (US)
* Hostname: h#### (use Gateway ID)
* Full name: HDC Admin
* Username: hdcadmin
* Encrypt home: Yes
* Time zone: Pacific
* Partitioning: Guided - use entire disk and set up LVM
  * MMC/SD card #1
* Force UEFI installation: Yes
* Manage upgrades: No automatic updates
* Software selection: OpenSSH server


## 2. Prepare System

Log in remotely as hdcadmin:

* `ssh hdcadmin@<IP_Address>` and provide credentials


Update System

* `sudo apt update`
* `sudo apt upgrade -y`
* `sudo apt dist-upgrade -y`
* `sudo update-grub`

Install Make and Git (note: apt-get for Ubuntu 14.04)

* `sudo apt update` (skip if recently run)
* `sudo apt install make git -y`

Create Directory and Clone This Repository

* `sudo mkdir /hdc/`
* `sudo chown -R hdcadmin:hdcadmin /hdc/`
* `cd /hdc/`
* `git clone https://github.com/HDCbc/endpoint`


## 3. Select and Begin Installation

Follow 3.a) or 3.b)


### 3.a) HDC-Managed Solution

Run Makefile

* `cd /hdc/endpoint`
* `make hdc`


### 3.b) Self-Managed Solution

Run Makefile

* `cd /hdc/endpoint`
* `make`


## 4. Config.env

Configure config.env


## 5. Post Installation

Send the following information to admin@pdcbc.ca:

* Clinic name and address
* Physician names and CPSIDs
* id_rsa.pub
  * This will be output during step 4.
