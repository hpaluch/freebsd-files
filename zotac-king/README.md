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
- these two lines from `zfs history` are life-savers:
  ```
  zpool set bootfs=zroot/ROOT/default zroot
  zpool set cachefile=/mnt/boot/zfs/zpool.cache zroot
  ```

Below is my new EFI boot entry:
```shell
root$ efibootmgr -v | fgrep King

+Boot0009* FreeBSD-King HD(1,GPT,a488a6ef-393c-11f0-a7a9-00012e7a5ff8,0x28,0x82000)/File(\EFI\FREEBSD\LOADER.EFI)
```

# Setup log

I will try to describe all changes I did to be able to reproduce this setup later.

After reboot I had to fix swap partition name in `/etc/fstab`
- from `/dev/da2p3` to `/dev/da1p3`
- it is because USB stick caused target SSD to be 3rd device instead of 2nd when
  it was removed on reboot

I installed several basic packages so I can manage this git repo:
- installed
  ```shell
  pkg install git-lite mc vim tmux doas lynx fastfetch
  ```
- created `/usr/local/etc/doas.conf` with:
  ```
  permit :wheel
  ```
- I added my ordinary user to group `wheel` for that to work.


Set readable font by adding to `/etc/rc.conf` - from: https://forums.freebsd.org/threads/how-to-make-vt-console-switch-to-the-default-terminus-bsd-font.67888/):

```shell
allscreens_flags="-f vgarom-16x32"
```

- note: above size is perfect on my `Full HD` (1920x1080) monitor

Installed ports and sources
```shell
curl -fLO https://download.freebsd.org/releases/amd64/14.2-RELEASE/ports.txz
curl -fLO https://download.freebsd.org/releases/amd64/14.2-RELEASE/src.txz
doas tar xpvf src.txz -C /
doas tar xpvf ports.txz -C /
```

Updating base system:
```shell
# run as root:
freebsd-update fetch
freebsd-update install
reboot
```

# Installing X11 with Xfce4

I have i915 graphics. I plan to use Xfce4.

Install packages specific to i915:
```shell
pkg install drm-kmod libva-intel-media-driver gpu-firmware-intel-kmod-broxton
kldload i915kms
sysrc kld_list+=i915kms
```

Common install instructions (independent of GPU):
```shell
pkg install xf86-input-keyboard xf86-input-mouse xf86-input-evdev xf86-input-synaptics
pkg install xorg xorg-server xorg-apps
pkg install xorg-fonts-100dpi xorg-fonts-75dpi xorg-fonts-miscbitmaps xorg-fonts-truetype xorg-fonts-type1

# run as root
pw groupmod video -m USERNAME
pkg install glx-utils
```

X11 Desktop environment (Xfce4) and favourite apps:

```shell
pkg install xfce
# browsers + PDF viewer
pkg install firefox-esr chromium evince-lite
# audio and video player
pkg install qmmp-qt5 mpv
```
Recommended: reboot system with `reboot`

Then we can use:
- `startxfce4` to run Xfce4
- `startx` to run good old TWM (useful as fallback)

NOTE: I have no plan to use Login manager (like `sddm`) - I like to try if most
tasks can be still done in text console (except viewering PDFs etc)...

