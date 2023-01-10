# ansible repository

Ansible is an automisation, provisioning and configuration management utility.

# How to use it?

- you need ansible installed (**version 2.4**, other might work as well)

# How to setup the gsm-tester?

`ansible-playbook -i hosts setup-gsm-tester.yml`

Your ssh key need to be deployed on the host.
Further information on this job can be found in **setup-gsm-tester.md**.

# How to setup a jenkin slave?

`ansible-playbook -i hosts setup-jenkins-slave.yml`

Further information on this job and around the setup can be found on the redmine wiki.

If you don't have access to an IPv6 network from your local host, then you can
use an ssh proxy to updates hosts in the `hosts` files being accessed only
through an IPv6 addr. Your ssh proxy must of course have an IPv6 address able to
reach the destination host.

example `.ssh/config`:
```
Host 2a01:4f8:13b:828::1:*
ProxyJump proxyuser@myhostproxy.com:22
User root
```

# how to make slaves log-in to registry.osmocom.org:

`ansible jenkins_slaves -u root -a "su - osmocom-build -c 'docker login -u jenkins_slave -p PASSWD https://registry.osmocom.org/'"`
