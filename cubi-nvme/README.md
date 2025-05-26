# FreeBSD on MSI Cubi NVMe SSD

My main workstation on MSI Cubi. Key details from `fastfetch`:

* Host: `PRO ADL-U Cubi 5 (MS-B0A8) (1.0)`
* CPU: `12th Gen Intel(R) Core(TM) i5-1235U (12) @ 4.40 GHz` (10 cores, 12 threads,
  only 2 cores are high performance with 2 threads each => 12 total threads)
* GPU: `Intel Iris Xe Graphics [Integrated]` - using same driver
  as for `HD 500` on Zotac - `i915kms`
* RAM: 32GB
* System disk: NVMe `GIGABYTE AG450E500G-G` 500GB

Currently my main OS on Cubi is `openSUSE LEAP 15.6 w Xfce`, however it may
change in future to FreeBSD (it depends how many and how severe road blocks I
will face).

I actually cloned this system from ZFS export - done
from machine/disk: [../zotac-king/](../zotac-king).

1. I created ZFS backup of Zotac to NFS server using my guide
   on :https://github.com/hpaluch/hpaluch.github.io/wiki/ZFS#zfs-backup
2. Next moved that backup from NFS server to additional partition on
   bootable stick with FreeBSD
3. Restored ZFS - based
   on :https://github.com/hpaluch/hpaluch.github.io/wiki/ZFS#zfs-restore
   but see text below...
4. Must update `/mnt/etc/fstab` to use proper devices
5. again disabled UART1 to boot (forgot that, err...)


Here are details:

I created backup from FreeBSD system running on Zotac using standard set of commands:
- note my `/etc/fstab` has entry like: `192.168.0.3:/i-data/0e5cf602/nfs/data /nfs nfs	rw,noauto 0 0`

Here are my commands to create full ZFS backup of "source" FreeBSD running on
Zotac server (excluded EFI and legacy BIOS boot partitions):

```shell
mount /nfs # details in /etc/fstab
mkdir /nfs/fbsd-zotac-king
zfs snapshot -r zroot@migrate
zfs send -Rc zroot@migrate | gzip -1c > /nfs/fbsd-zotac-king/zfs-backup.bin.gz
sync
umount /nfs                                                                            
```

However for restore I used rather 16GB USB stick for transfer from existing
backup on NFS server to avoid hassle with network configuration
- so still on source FreeBSD on Zotac:
- inserted stick already written with standard `FreeBSD-14.2-RELEASE-amd64-memstick.img`
  image
- next I added new FAT32 partition (to write there ZFS snapshot and my recovery notes):
  
  ```shell
  gpart show da2
  # create FAT32 partition using remaining space - around 14GB on 16GB stick.
  gpart add -t fat32lba da2 # please recheck - from my memory
  newfs_msdos -F32 /dev/da2s3
  mkdir /target
  mount -t msdosfs /dev/da2s3 /target
  mount /nfs #  backup NFS server details are in /etc/fstab
  # copy existing backup from NFS server to USB stick, split every 3GB
  # (FAT32 limits maximum file size to 4GB)
  split -b 3g - /target/zfs-backup.bin.gz. < /nfs/fbsd-zotac-king/zfs-backup.bin.gz   
  umount /target
  sync 
  ```

- remember to properly eject USB device with (will be moved from source Zotac
  to target Cubi) see [../README.md](../README.md) for details:

```shell
usbconfig list
# command below depends on list output!
usbconfig -u 0 -a 6 power_off
```

To clone this backup to Cubi target I did:
- normally boot FreeBSD from my modified USB stick (that has additional partition with backup)
- next I selected `Live System`
- next I did:

```shell
camcontrol devlist # find USB stick device: da0
mount -u -o rw  # remount USB stick / to read-write
mkdir -p /mnt2/source  # create mountpoint
# now mount my FAT32 parttiion with backup read-only:
mount -r -t msdosfs /dev/da0s3 /mnt2/source

# it was former Fedora partition (seen as "linux-data" in gpart):
# now retyped to "freebsd-zfs":
gpart modify -i 3 -t freebsd-zfs nda0
```

To find all used ZFS commands you can simply look into
[info/info-zfs.txt](info/info-zfs.txt) following `zfs history` command:

```shell
zpool create -o altroot=/mnt -O compress=on -O atime=off -m none cbsd nda0p3
# this command is from shell histroy ('zfs history' does not see other commands in pipe):
cat /mnt2/source/*.gz.a? | zcat |  zfs recv -F cbsd
zpool set bootfs=cbsd/ROOT/default cbsd
zpool export cbsd
```

Note: my target system already had valid EFI partition + ext4 partition with `openSUSE LEAP 15.6`
- mounted EFI on `/efi` and:
- copied `/boot/loader.efi` to `/efi/EFI/freebsd/loader.efi`
- then rebooted to SUSE
- and used `efibootmgr` to add new FreeBSD entry

```shell
efibootmgr -v      # list existing entries
efibootmgr -B -b 2 # delete entry 2 - Fedora (just replaced with FreeBSD)
# finally add new boot entry:
efibootmgr -c -L FreeBSD-NVMe -l '\EFI\freebsd\loader.efi'
```

Still on SUSE I also prepared chained GRUB entry in `/etc/grub.d/40_custom`:
```
menuentry 'FreeBSD NVMe' --id freebsd-nvme  {
        insmod part_gpt
        insmod fat
        insmod chain
		# D053-8E73 is my serial number of EFI FAT partition
        # used "lsblk -f" to reveal it:
        search --no-floppy --fs-uuid --set=root D053-8E73
        chainloader /EFI/freebsd/loader.efi
}    
```

And regenerated `/boot/grub2/grub.cfg` using `grub2-mkconfig -o /boot/grub2/grub.cfg`

And now I'm ready to reboot from SUSE to freshly installed (err, cloned) FreeBSD!

Changes:
- must disable UART1 to boot at all. Please see 
  my wiki on https://github.com/hpaluch/hpaluch.github.io/wiki/FreeBSD-on-Cubi for details
- my ZFS pool is now called `cbsd` (Cubi BSD) instead of `zroot` - main reason is that
  many installations often use `zroot` without chance to use another name.

