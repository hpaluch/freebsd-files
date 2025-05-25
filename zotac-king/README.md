# FreeBSD on Zotac Kingston

Here is my future FreeBSD workstation installed on:

* Zotac NANO (4 cores, 4GB RAM)
* SSD Kingston SA480 attached on `USB->SATA` adapter
* using ZFS

Details:
- installed from `FreeBSD-14.2-RELEASE-amd64-memstick.img`
- UEFI mode
- `AutoZFS` layout, stripe with single disk Kingston SA480
- you can find disk layout in [info/info-disk.txt](info/info-disk.txt)
- important ZFS commands including history are in [info/info-zfs.txt](info/info-zfs.txt)

# Setup log

I will try to describe all changes I did to be able to reproduce this setup later.

After reboot I had to fix swap partition name in `/etc/fstab`
- from `/dev/da2p3` to `/dev/da1p3`
- it is because USB stick caused target SSD to be 3rd device instead of second

I installed several basic packages so I can manage this git repo:
- installed
  ```shell
  pkg install git-lite mc vim tmux doas
  ```
- created `/usr/local/etc/doas.conf` with:
  ```
  permit :wheel
  ```
- I added my ordinary use to group `wheel` for that to work.


