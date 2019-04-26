# Install the poky sdk's used to build sysmobts binaries

# Poky Installation

The poky installation requires you to have the installer available.
Put the `poky_installer_file` to the root directory of this repo.
Also the exact filename must match the variable `poky_installer_file`

example:
```
    - name: install-poky-sdk
      jenkins_user: osmocom-build
      poky_install_file: poky-glibc-x86_64-meta-toolchain-osmo-cortexa15hf-neon-toolchain-osmo-2.3.4-20190426050512.sh
      poky_dest: /opt/poky-sdk/2.3.4/
      tags:
        - poky
```
