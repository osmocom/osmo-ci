# Setup the osmo-gsm-tester

The playbook `setup-gsm-tester.yml` setup a full working osmo-gsm-tester.

# Requirements

The remote host needs to be added to the `hosts` file under the section `osmo-gsm-tester`.
It also needs to install python and have the **contrib non-free** repositories enabled in `/etc/apt/sources.list`.

## 3rd party firmware

To have the non-free gobi firmware installed, those files must be placed
files/gobi/UQCN.mbn
files/gobi/amss.mbn
files/gobi/apps.mbn


# Steps after the playbook ran

The jenkins user needs to know the ssh-keys of all BTS which get accessed via ssh.
	E.g. the gsm-tester is connecting to a sysmobts via ssh.

The main unit needs to be logged in with docker repo registry.sysmocom.de:
	docker login -u "osmo-gsm-tester" registry.sysmocom.de
