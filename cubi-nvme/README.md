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

1. I created ZFS backup following my guide
   on :https://github.com/hpaluch/hpaluch.github.io/wiki/ZFS#zfs-backup
2. Restored ZFS - based
   on :https://github.com/hpaluch/hpaluch.github.io/wiki/ZFS#zfs-restore
3. Must update `/mnt/etc/fstab` to use proper devices
3. again disabled UART1 to boot

NOTE: However I rather used local boot flash instead of NFS:
- there was free space on USB stick (around 14GB from 16GB total),
  so I created another partition with FAT32 filesystem
- export ZFS datasets there with `split` command, because FAT32 supports
  maximum file system 4GB

To find all used ZFS commands you can simply look into [info/info-zfs.txt](info/info-zfs.txt)
following `zfs history` command:
```
zpool create -o altroot=/mnt -O compress=on -O atime=off -m none cbsd nda0p3
zfs recv -F cbsd
zpool set bootfs=cbsd/ROOT/default cbsd
zpool export cbsd
```

The `zfs recv` was called in pipe using something like:

```shell
cat /mnt2/source/*.gz.a? | zcat | zfs recv -F cbsd
```

(files geneated with `zfs send ...` ending with `gzip -9c | split -b 3g - /mnt2/stick/file.gz.`)

Changes:
- must disable UART1 to boot at all. Please see 
  my wiki on https://github.com/hpaluch/hpaluch.github.io/wiki/FreeBSD-on-Cubi for details
- my ZFS pool is now called `cbsd` (Cubi BSD) instead of `zroot` - main reason is that
  many installations often use `zroot` without chance to use another name.

