# My FreeBSD files

Here are my FreeBSD configuration files from various machines.

List of machines:

* [Cubi MSI w NVMeSSD ](cubi-nvme/) - my latest workstation
* [Zotac CI327NANO Samsung SSD](zotac-ssd/)
* [Zotac CI327NANO Kingston SSD+ZFS](zotac-king/) - my new reference
  installation (possibly replacing my "openSUSE LEAP with Xfce" in near future.

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

* run `top` to show with command arguments - use `-a` instead of `-c`: `top -a`
* show open tcp and udp sockets: `sockstat -46`
* ps tree - use `d` instead of `f`, for example: `ps axd`

## Ejecting USB device:

From https://forums.freebsd.org/threads/usb-eject.58822/

```shell
$ usbconfig list

ugen0.1: <Intel XHCI root HUB> at usbus0, cfg=0 md=HOST spd=SUPER (5.0Gbps) pwr=SAVE (0mA)
ugen0.3: <Bluetooth wireless interface Intel Corp.> at usbus0, cfg=0 md=HOST spd=FULL (12Mbps) pwr=ON (100mA)
ugen0.4: <3-in-1 (SD/SDHC/SDXC) Card Reader Realtek Semiconductor Corp.> at usbus0, cfg=0 md=HOST spd=HIGH (480Mbps) pwr=ON (500mA)
ugen0.5: <JMS567 SATA 6Gb/s bridge JMicron Technology Corp. / JMicron USA Technology Corp.> at usbus0, cfg=0 md=HOST spd=SUPER (5.0Gbps) pwr=ON (2mA)
ugen0.6: <Ultra SanDisk Corp.> at usbus0, cfg=0 md=HOST spd=SUPER (5.0Gbps) pwr=ON (224mA)
ugen0.2: <PS/2 Keyboard+Mouse Adapter Chesen Electronics Corp.> at usbus0, cfg=0 md=HOST spd=LOW (1.5Mbps) pwr=ON (100mA)

$ usbconfig -u 0 -a 6 power_off
```

where `-u 0` is USB  bus index (first number in `ugen0.6`), and `-a 6` is address (second number in `ugen0.6`).

- as bonus you can even see power consumption!
- NOTE: after `power_off` the `usbconfig list` will still show that device but this time with `pwr=OFF`

## List installed packages

There exist command to list only installed packaages but without
automatic dependencies:

```shell
pkg prime-list
```

Source: FreeBSD Handbook

## Mounting Linux ext4 filesystem


Note: probably Linux LVM is not supported nor BTRFS (did not find info how to do that).

Requirements:
- having inserted `fusefs` module in kernel - ensure that there is `fusefs` on this line
  in `/etc/rc.conf`

  ```shell
  kld_list="vmm i915kms fusefs nmdm"
  ```

  Also you can load it on demand using `kldload fusefs` and/or see
  module list with `kldstat`

- install at least: `pkg install fusefs-ext2`

Now find proper device name (I want to mount Linux partition from NVMe):
```shell
root# camcontrol devlist

<Samsung SSD 870 QVO 1TB SVQ02B6Q>  at scbus0 target 0 lun 0 (pass0,ada0)
<GIGABYTE AG450E500G-G ELFMB0.6>   at scbus2 target 0 lun 1 (pass1,nda0)
```

So my NVMe is `nda0`

Now find partition names on `nda0`:
```shell
root# gpart show nda0

=>       34  976773101  nda0  GPT  (466G)
         34       2014        - free -  (1.0M)
       2048    1048576     1  efi  (512M)
    1050624  780140544     2  linux-data  (372G)
  781191168  195581952     3  freebsd-zfs  (93G)
  976773120         15        - free -  (7.5K)
```

My Linux data partition is number `2` (`linux-data` with size 372G).

So full device name will be `/dev/nda0p2` (you can also use
`ls /dev/nda0*` to find likely device name).

Finally I did:
```shell
root# fuse-ext2 -o ro /dev/nda0p2 /mnt/suse
```

To read-only mount my existing `ext4` partition under `/mnt/suse`.

