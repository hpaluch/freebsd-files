# My FreeBSD files

Here are my FreeBSD configuration files from various machines. As of `May 2025` I
use FreeBSD 14.2.

List of machines:

* [Cubi MSI w NVMeSSD ](cubi-nvme/) - my latest workstation
* [Zotac CI327NANO Samsung SSD](zotac-ssd/)
* [Zotac CI327NANO Kingston SSD+ZFS](zotac-king/) - my new reference
  installation (possibly replacing my "openSUSE LEAP with Xfce" in near future.

# Common files

Complete common file tree is under [common-tree/](common-tree/).

Some changes are also under [patches/](patches/) to better understand
what exactly changed.

- enable UTF-8 in Lynx browser output (by default Lynx expects ISO-8859-1
  output terminal), see
  [patches/lynx-enable-utf8.patch](patches/lynx-enable-utf8.patch).  I verified
  this setup with following line in `/etc/rc.conf` to have local console with
  clean readable and surprisingly UTF-8 compatible font:

  ```shell
  # set sane console font, from https://forums.freebsd.org/threads/how-to-make-vt-console-switch-to-the-default-terminus-bsd-font.67888/
  allscreens_flags="-f vgarom-16x32"
  ```

# BHYVE grub Alpine fix

> [!WARNING]
> 
> If you have more than 1 FreeBSD machine with bridge on same network
> always double-check that each bridge has *unique* MAC address!
> If you cloned your machine (I did with ZFS) you *must* regenerate `/etc/hostid`
> on target machine with command: `/etc/rc.d/hostid reset`
> and reboot!


If you plan to use `grub-bhyve` to boot Linux directly from FreeBSD host
(without UEFI) you must very carefully set/unset compatible ext4 filesystem
features.

Here is what happened to me:

- tested `grub-bhyve` from package `grub2-bhyve-0.40_11`
- Debian 12 from `debian-12.9.0-amd64-netinst.iso` worked perfectly with
  `grub-bhyve` with default installation (single `ext4` partition with Grub,
  MBR partitioning)
- but Alpine Linux from `alpine-virt-3.21.3-x86_64.iso` did not work even when
  I carefully manually partitioned disk (to really use `ext4` for boot and
  manually installed its Grub instead of default `extlinux`
- unfortunately it still did not work - `grub-bhyve` just reported `Unknown filesystem`
- so I compared feature flags using following trick (shown for Alpine):

  ```shell
  pkg install e2fsprogs-core # provides tune2fs
  mdconfig /zroot/bhyve/images/alpine1/alpine1.raw
  tune2fs -l /dev/md0s1 | fgrep features
  ```

- comparing installed Alpine with installed Debian ext4 features I quickly
  found differences ( ignore those with `-` missing Alpine when compared
  to Debian, `needs_recover` was there because I run tune2fs directly in Debian
  on mounted fs):

  ```diff
  --- ../deb12-test/deb12-features-list.txt	2025-05-31 15:16:39.295620000 +0200
  +++ alpine-features-list.txt	2025-05-31 15:14:12.241460000 +0200
  @@ -1,4 +1,3 @@
  -64bit
   dir_index
   dir_nlink
   ext_attr
  @@ -10,6 +9,7 @@
   huge_file
   large_file
   metadata_csum
  -needs_recovery
  +metadata_csum_seed
  +orphan_file
   resize_inode
   sparse_super
  ```

- important incompatible features are `metadata_csum_seed` and `orphan_file`
- using prepared `md0` device (see above text) I just did:

  ```shell
  tune2fs -O ^orphan_file,^metadata_csum_seed /dev/md0s1
  tune2fs -l /dev/md0s1 | fgrep features
  # unbind .raw file from md0
  mdconfig -du md0
  ```

-  after this small tweak I was able to boot Alpine using `grub-bhyve`,
   just needed typical commands in grub prompt:

   ```
   set root='(hd0,msdos1)'
   configfile /boot/grub/grub.cfg
   ```

You can see my boot scripts and `device.map` for Alpine Linux
under [cubi-nvme/home/vm/vms/alpine1](cubi-nvme/home/vm/vms/alpine1).

# BHYVE examples

Do not forget to install at least:

```shell
pkg install bhyve-firmware grub2-bhyve
```

And add `vmm` to kernel modules list.

New: Direct Linux guest loading using `grub2-bhyve` -
see [zotac-king/opt/images/trac-dr](zotac-king/opt/images/trac-dr) folder for example.

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

# Linux to FreeBSD notes

* run `top` to show with command arguments - use `-a` instead of `-c`: `top -a`
* show open tcp and udp sockets: `sockstat -46s` (small `-s` will show socket status,
  like netstat on Linux)
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

Where `-u 0` is USB  bus index (first number in `ugen0.6`), and `-a 6` is address (second number in `ugen0.6`).

- as bonus you can even see power consumption!
- NOTE: after `power_off` the `usbconfig list` will still show that device but this time with `pwr=OFF`

## List installed packages

There exists command to list only installed packages but without
automatic dependencies (exactly what I want):

```shell
pkg prime-list
```

Source: FreeBSD Handbook

## Mounting Loopback file as disk

Simply:
```shell
root@fbsd-cubi# mdconfig /zroot/bhyve/images/alpine1/alpine1.raw

md0

root@fbsd-cubi# mdconfig -lv

md0     vnode    2048M  /zroot/bhyve/images/alpine1/alpine1.raw

root@fbsd-cubi# gpart show md0

=>     63  4194241  md0  MBR  (2.0G)
       63     1985       - free -  (993K)
     2048   614400    1  linux-data  [active]  (300M)
   616448  1048576    2  linux-swap  (512M)
  1665024  2529280    3  linux-data  (1.2G)

root@fbsd-cubi# ls  /dev/md0*

/dev/md0        /dev/md0s1      /dev/md0s2      /dev/md0s3

root@fbsd-cubi# file /dev/md0s3  # err - it is true, but useless:

/dev/md0s3: character special (1/186)

root@fbsd-cubi# file -s /dev/md0s3  # -s required to query content of device:

/dev/md0s3: Linux rev 1.0 ext4 filesystem data, \
   UUID=f729e272-2d86-42f7-9b51-3562593544ea (extents) \
   (64bit) (large files) (huge files)
```

Removing loopback device:
```shell
root@fbsd-cubi# mdconfig -lv

md0     vnode    2048M  /zroot/bhyve/images/alpine1/alpine1.raw

root@fbsd-cubi# mdconfig -du md0
root@fbsd-cubi# mdconfig -lv

(empty output)
```

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

My NVMe is `nda0`

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

## Connecting MTP Device - Kindle Fire tablet

Note:

- in the past most devices pretended to be `USB Mass storage` (including e-ink
  Kindle 3). However it caused lot of issues, because PC would directly modify
  it as block device - meaning that it could modify filesystem in way that was
  unsupported by Device or even reformat it to completely unsupported filesystem.
  Also it was not possible for Device to safely access storage while connected
  to Host PC and/or detect changed objects (directories, files) on such storage.

  It was such pain that some Sony movie cameras allowed read-only access from PC
  (only Camera was allowed to format SD card or write new files to SD card).

- so new `MTP device` class was created where PC issues filesystem object
  operations, but no longer has direct access to block storage. This allows for
  safety checks on Device and to easily detect modified files on Device storage.

You need to do for the first time:
- have loaded `fusefs` module - see previous section for instructions
- install: `pkg install fusefs-jmtpfs`
- create mount point: `mkdir -p /mnt/fire`

Next you need to just:
- connect tablet to PC
- verify that tablet was found with `usbconfig list`
- mount it with simple command:

```shell
root# jmtpfs /mnt/fire/

Device 0 (VID=1949 and PID=0008) is a Amazon Kindle Fire (ID2).
Android device detected, assigning default bug flags```

root# ls -l /mnt/fire

total 0
drwxr-xr-x  21 root wheel 0 bad date val Internal storage
```

Don't be scared with `bad date val` - important is `Internal storage`
which is accessible folder on Tablet.

Here is example, how I copied PDF to Tablet:
```shell
root# cp ~USERNAME/Documents/articles/freebsd/zfs-cheatsheet-en.pdf \
   /mnt/fire/Internal\ storage/Documents/
```

You can verify on Kindle "Newsstand" view that Document was really uploaded.

Finally remember to cleanly unmount and disconnect tablet:

```shell
root# umount /mnt/fire/
root# usbconfig list | fgrep Fire

ugen1.10: <Amazon Kindle Fire HD 8.9" Lab126, Inc.> at usbus1, cfg=0 md=HOST spd=HIGH (480Mbps) pwr=ON (2mA)

root# usbconfig -u 1 -a 10 power_off
```
And disconnect tablet.

## BitLocker support

I plan to use USB Stick formatted with FAT32 (supported well on all systems
including FreeBSD) and encrypted using old BitLocker.

However original FreeBSD port of BitLocker (`libbde` package) has bug that
prevents to work properly (it tries to read smaller block than 512 bytes from
block device, which is not allowed by FreeBSD kernel).

I'm currently proposing fix at:
- https://forums.freebsd.org/threads/mount-an-encrypted-usb-drive-on-freebsd-and-windows.90789/

