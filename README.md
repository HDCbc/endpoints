# HDC Endpoints
## Self- and HDC-Managed Deployment Options

HDC Endpoint deployments for self- and HDC-managed options.


## 0. Prerequisites

Information:

* Pre-approval from the Health Data Coalition
* Four digit (####) Gateway ID for Endpoints
* Doctor CPSIDs
* IP address data will be exported from


Operating system:

* [Ubuntu Server 16.04 (LTS)](http://www.ubuntu.com/download/server/thank-you?version=16.04.1&architecture=amd64)


Server hardware:

* Lenovo M92p SFF - i7-3770, 8GB RAM, 1TB HD (1st gen deployment)
* Lenovo M93p SFF - i7-4770, 8GB RAM, 1TB HD (2nd gen deployment)
* HP Pavilion Mini - Pentium 3558U, 4GB RAM, 500GB HD (3nd gen deployment)
* InFocus Kangaroo Pro - Atom x5-Z8500, 2GB RAM, 32GB HD (4th gen deployment)


Note: Guide is tailored to current generation hardware.


## 1. Install Operation System

Boot from Ubuntu media

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

* `ssh hdcadmin@HOSTNAME`, where HOSTNAME=h#### (use Gateway ID)
* Or `ssh hdcadmin@<IP_ADDRESS>`, if the IP is known


Optional: Update System

* `sudo apt update`
* `sudo apt upgrade -y`
* `sudo apt dist-upgrade -y`
* `sudo update-grub`


Install Make and Git (note: Ubuntu 16.04 can use `apt` or `apt-get`)

* `sudo apt-get update` (skip if recently run)
* `sudo apt-get install make git -y`


Create Directory and Clone This Repository

* `sudo mkdir /hdc/`
* `sudo chown -R hdcadmin:hdcadmin /hdc/`
* `cd /hdc/`
* `git clone https://github.com/HDCbc/endpoint`


## 3. Select and Begin Installation

Follow a) or b)


### a) HDC-Managed Solution

Run Makefile

* `cd /hdc/endpoint`
* `make hdc`


### b) Self-Managed Solution

Run Makefile

* `cd /hdc/endpoint`
* `make`

### id_rsa.pub

This will be output shortly after configuring config.env in the next step.
Please send it (or a copy/paste with the line breaks intact) to admin@hdcbc.ca.


## 4. Config.env

Configure config.env:

* GATEWAY_ID - provided by the HDC
* DOCTOR_IDS - list of doctor CPSIDs, separated by commas (e.g. 123245,23456)
* IP_STATIC  - desired IP address, for HDC managed solution
* DATA_FROM  - exporting server, to be allowed through the firewall


## 5. SSH - HDC Managed Solution

For HDC managed solutions id_rsa.pub will be echoed to the screen.  Please send
this (file: /root/.ssh/id_rsa.pub, or copy/paste with line breaks intact) to
admin@hdcbc.ca.


## 6. File Encryption - HDC Managed Solution

Follow defaults when setting up encfs.  Choose and record a strong password!


## 7. Post Installation Checklist

Send the following information to admin@pdcbc.ca:

* Clinic name and address
* Physician names and CPSIDs
* id_rsa.pub
  * This will be output during step 3.

Verify that monit, ufw and all tunnels are functioning


## 8. Operation an Endpoint

Self-managed Endpoints should work as-is, assuming key are in place and there
are no other complications.

HDC-managed Endpoints will not allow Docker to start or access to the exporting
server until /hdc/decrypt.sh is run and the encryption password provided.  The
HDC will monitor and intervene as necessary.


## 9. Troubleshooting

View logs with systemd (Ubuntu 16.04 only)

* `cd /hdc/endpoint`


View logs files on host

* `tail -f /var/log/auth.log`
