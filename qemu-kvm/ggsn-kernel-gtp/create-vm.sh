#!/bin/sh

set -e -x

tar czvf postinst.tar.gz postinst

virt-install \
	--connect qemu:///system \
	--virt-type kvm \
	--name debian9 \
	--memory 1024 \
	--disk path=./debian9.qcow2,size=8 \
	--vcpus 1 \
	--os-type linux \
	--os-variant debian9 \
	--network bridge=lxcbr0 \
	--graphics none \
	--console pty,target_type=serial \
	--location 'http://ftp.de.debian.org/debian/dists/stretch/main/installer-amd64/' \
	--initrd-inject ./preseed.cfg \
	--initrd-inject ./postinst.sh \
	--initrd-inject ./postinst.tar.gz \
	--extra-args 'auto=true hostname=ggsn domain="" console=ttyS0,115200n8 serial'
