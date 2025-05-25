# My FreeBSD files

Here are my FreeBSD configuration files from various machines.

List of machines:

* [Zotac CI327NANO Samsung SSD](zotac-ssd/)
* [Zotac CI327NANO Kingston SSD+ZFS](zotac-king/)

# BHYVE examples

You can find required things in 2 places:

- bridged network card with `tap0,1,2` devices in [zotac-ssd/etc/rc.conf](zotac-ssd/etc/rc.conf)
  These sections are important (commented out is original network configuration):

  ```shell
  # original network configuration (before bridge):
  #ifconfig_re0="DHCP"
  #ifconfig_re0_ipv6="inet6 accept_rtadv"
  
  # bridge 'bridge0' and tap0,1,2 devices (each for 1 VM):
  ifconfig_re0="up"
  ifconfig_bridge0="inet 192.168.0.50/24 addm re0 addm tap0 addm tap1 addm tap2"
  cloned_interfaces="bridge0 tap0 tap1 tap2"
  static_routes="ext"
  route_ext="-net 0.0.0.0/0 192.168.0.1"
  # also these modules were added: (ignore i915kms - not related to bhyve):
  kld_list="vmm i915kms fusefs nmdm"
  ```

- example installation script from Alpine Linux VM
  is [zotac-ssd/opt/images/alpine1/run-install.sh](zotac-ssd/opt/images/alpine1/run-install.sh):

  ```shell
  #!/bin/sh
  set -xeu
  vm=alpine1
  disk=/opt/images/$vm/disk1.img
  iso=/opt/iso/alpine-virt-3.20.3-x86_64.iso
  tap=tap0
  
  bhyve -AHP -s 0:0,hostbridge -s 1:0,lpc \
          -s 2:0,virtio-net,$tap -s 3:0,virtio-blk,$disk \
          -s 4:0,ahci-cd,$iso -c 1 -m 1024M \
  	-l com1,stdio \
          -l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd,/opt/images/$vm/BHYVE_UEFI_VARS.fd \
          $vm
  exit 0
  ```

- example script to boot from disk after installation:
  [zotac-ssd/opt/images/alpine1/run-disk.sh](zotac-ssd/opt/images/alpine1/run-disk.sh)

  ```shell
  #!/bin/sh
  set -xeu
  vm=alpine1
  disk=/opt/images/$vm/disk1.img
  tap=tap0
  
  bhyve -AHP -s 0:0,hostbridge -s 1:0,lpc \
          -s 2:0,virtio-net,$tap -s 3:0,virtio-blk,$disk \
          -c 1 -m 1024M \
  	-l com1,stdio \
          -l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd,/opt/images/$vm/BHYVE_UEFI_VARS.fd \
          $vm
  exit 0
  ```

# Linux to FreeBSD glossary

* show top with commands: `top -a`
* show open tcp and udp sockets: `sockstat -46`

