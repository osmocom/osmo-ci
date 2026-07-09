The scripts in this directory are used to create an archive of Osmocom related
packages from OBS, at: https://downloads.osmocom.org/obs-mirror/

There is no mechanism in place to deploy updated scripts after updating them
here in osmo-ci.git, so this must be done manually:

```
$ ssh pkgmirror@package-archive.osmocom.org
pkgmirror@package-archive:~$ git -C osmo-ci pull
```

After changing the systemd services or timers, deploy them as follows:
```
$ scp systemd/* root@package-archive.osmocom.org:/etc/systemd/system
$ ssh root@@package-archive.osmocom.org
root@package-archive:~# systemctl daemon-reload
```

See OS#4862 for more information.
