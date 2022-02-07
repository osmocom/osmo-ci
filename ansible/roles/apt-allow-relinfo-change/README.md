---
When the suite of one debian release changes from stable to oldstable, apt
stops working with the following error:

```
W:This must be accepted explicitly before updates for this repository can be applied. See apt-secure(8) manpage for details.
E:Repository 'http://raspbian.raspberrypi.org/raspbian buster InRelease' changed its 'Suite' value from 'stable' to 'oldstable'
```

This role configures apt to allow the release info change.

Related: https://github.com/ansible/ansible/issues/48352
