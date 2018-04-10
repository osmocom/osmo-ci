---
Install and configure udhcpd.

```
    - name: udhcpd
      udhcpd_router: 10.42.42.1
      udhcpd_range_start: 10.42.42.230
      udhcpd_range_end: 10.42.42.230
      udhcpd_netmask: 255.255.255.0
      udhcpd_dns: 10.42.42.2
      udhcpd_interface: enp2s0
      udhcpd_static_leases:
        - mac: 00:12:34:56:78:9a
          ip: 10.42.42.53
```
