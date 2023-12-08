# Osmocom CI and infrastructure files

## ansible
Ansible rules for setting up machines of the Osmocom infrastructure.
See `ansible/README.md`.

## contrib
Scripts and files that did not fit into other directories.

## coverity
Scripts used to submit the osmocom sources for coverity scan.
This depends on these, which are not included in osmo-ci:
- a tokens.txt file in coverity/ -- see coverity/get_token.sh
- a cov-analysis-linux64-8.5.0 in coverity/
  (or the like, may need to adjust some scripts to match)

## jobs
Jenkins Job Builder YAML files defining jenkins jobs. Read `jobs/README.adoc`
for more information about deployment.

## lint
The linter running on patches submitted via gerrit. See the wiki page
[Linting](https://osmocom.org/projects/cellular-infrastructure/wiki/Linting)
for more information.

## qemu-kvm
A script to create a virtual machine with kernel gtp ggsn for qemu-kvm.

## scripts
Scripts used by jenkins jobs. Various `osmo*/contrib/jenkins.sh` scripts assume
osmo-ci to be checked out in the build slave user's home, i.e. using a PATH of
`$HOME/osmo-ci/scripts`.

## _docker_playground
A clone of
[docker-playground](https://gitea.osmocom.org/osmocom/docker-playground),
so the scripts can build required docker images. This dir gets created on
demand by scripts/common.sh, and automatically fetched and reset to
"origin/master" (override with `$OSMO_BRANCH_DOCKER_PLAYGROUND`). The fetch and
reset gets skipped if _docker_playground is a symlink. For development, set it
up as follows:

```
$ git clone https://gitea.osmocom.org/osmocom/docker-playground
$ git clone https://gitea.osmocom.org/osmocom/osmo-ci
$ cd osmo-ci
$ ln -s ../docker-playground _docker_playground
```
