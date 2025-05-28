# BHYVE Direct Linux boot

Here is example of direct Linux boot using bhyve-grub. See 
official handbook on https://docs.freebsd.org/en/books/handbook/virtualization/#virtualization-bhyve-linux

> WARNING! You need raw image file with installed Linux (tested Debian on MBR+BIOS) to really boot VM!
> Script expects image name `trac-dr.raw` in this directory (`/opt/images/trac-dr`).

How it works:
- Host loads GRUB loader
- GRUB Loader will load kernel and initramfs
- GRUB Loader will exit
- next script will activate VM with already loaded kernel

Most of this is done by script `10-run-grub.sh` (one only need to enter GRUB commands to load Menu).

