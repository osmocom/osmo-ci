# ansible repository

Ansible is an automisation, provisioning and configuration management utility.

# How to use it?

- you need ansible installed (version 2.4, other might work as well)

# How to setup the gsm-tester?

`ansible-playbook -i hosts setup-gsm-tester.yml`

Your ssh key need to be deployed on the host.
Further information on this job can be found in **setup-gsm-tester.md**.

# How to setup a jenkin slave?

`ansible-playbook -i hosts setup-jenkins-slave.yml`

Further information on this job and around the setup can be found on the redmine wiki.
