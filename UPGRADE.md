# Upgrading FreeBSD

How I upgraded FreeBSD.

# Upgrade 14.2 -> 14.3

> [!WARNING]
>
> There were 2 serious issues to overcome:
>
> 1. freezing old `loader.efi` on boot on Zotac Nano (resolved by copying updated
>    `/boot/loader.efi` to EFI target)
> 2. Crashing i915 kmod DRM driver on Cubi from `drm-515-kmod-5.15.160.1403000_4` package. Fortunately
>    alternative `drm-61-kmod-6.1.128.1403000_4` works without crash.

SO BACKUP YOUR DATA FIRST! I really mean it!

First step is easy:

```shell
# on existing 14.2 release:
# 1. ensure that your system 14.2 has latest updates:
freebsd-update fetch
freebsd-update install

# 2. now 1st stage of upgrade 14.2 -> 14.3
freebsd-update upgrade -r 14.3
freebsd-update install
```

Now tricky point - required at least on Zotac Nano (Broxton) - new
`loader.efi` - but I rather did it on both computers (Zotac and Cubi):

```shell
# Warning! on some systems there could be /boot/efi instead of /efi mount point:
cd /efi/EFI/freebsd/
mkdir old
mv loader.efi old
cp /boot/loader.efi .
```

Only then reboot with `reboot` command.

After reboot you will immediately notice that DRM i915 driver is not loaded -
console will be in very low resolution. But let first finish upgrade with:

```shell
# 3. after  reboot:
freebsd-update install
pkg update
pkg upgrade
```

Now dangerous stuff (at least on i915 GPU): finding working DRM driver: We will
filter only packages for `14.3` release (string `1403000_`):

```shell
pkg search -g 'drm*1403000_*'

  drm-515-kmod-5.15.160.1403000_4 DRM drivers modules
  drm-61-kmod-6.1.128.1403000_4  DRM drivers modules
```

Now important thing:

1. for Zotac Nano (Broxton - device `HD Graphics 500`) install (DRM from Linux kernel 5.15):

   ```shell
   pkg install drm-515-kmod
   ```

2. but for Cubi (device `Alder Lake-UP3 GT2 [Iris Xe Graphics]`) 
   you *must* install later driver (DRM from Linux kernel 6.1):

   ```shell
   pkg install drm-61-kmod
   ```

Now run:

```shell
sync # flush cashes in case of crash
kldload i915kms 
```

If your computer did not crash you won and you can enjoy FreeBSD 14.3!

