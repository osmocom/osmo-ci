# Setup a usual jenkins slave

Support the following variables:

* `install_jenkins_utilities`: (true) install usefull utilities including qemu/debootstrap/fakeroot
* `generic_slave`: (true) contains tasks used by the most osmocom jenkins slaves
* `osmocom_jenkins_slave_fstrim`: (false) calls fstrim periodical
* `ttcn3_slave`: (true) install titan ttcn3 compiler and prepares the docker-playground
* `jenkins_tmpfs`: (false) put jenkins workspaces and ccache dirs into tmpfs
