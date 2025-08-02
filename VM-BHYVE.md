# Testing VM-BHYVE

`vm-bhyve` is set of scripts for easier use of Virtualization (than direct use
of `bhyve` and related commands).  If you know Linux LibVirt - `vm-bhyve`
basically does some but as set of lightweight Bourne shell scripts instead of
bunch of heavy systemd services.

# Setup

First install few packages:

```shell
pkg install vm-bhyve bhyve-firmware grub2-bhyve
```

Next, if you are using ZFS, create dedicated dataset for `vm-bhyve`.
I have pool `cbsd` ("Cubi" BSD named by computer brand) and I created
`vm-bhyve` dataset right at the top of pool `cbsd`:

```shell
zfs create cbsd/vm-bhyve
```

Finally add to your `/etc/rc.conf`:
```shell
# vm-bhyve
vm_enable="YES"
vm_dir="zfs:cbsd/vm-bhyve"

# your module list should include "vmm" (bhyve)
# and "nmdm" (null modem for bhyve serial consoles)
kld_list="fusefs i915kms nmdm vmm"
```

Also I decided to NOT use my own manual bridges (I plan to create them in
`vm-bhyve`).  NOTE: you can still use them but I decided to learn `vm-bhyve`
capabilities.  Here is my IPv4+IPv6 networking using DHCPv4 + SLAAC (IPv6) in
`/etc/rc.conf` (Network card is `re0` RealTek NIC):

```shell
# original network without manual bridges:
ifconfig_re0="DHCP"
ifconfig_re0_ipv6="inet6 accept_rtadv"
```

NOTE: There is also one advantage - because `vm` service creates bridges
after `NETWORKING` stage but before `ipfw` firewall I can still use
`DHCP` configuration for my physical network - even with bridge managed
by `vm-bhyve`.


Next reboot with `reboot` command.

After reboot verify that your Network still works properly using:
```shell
ifconfig -u
netstat -ni
netstat -ri
curl -i www.freebsd.org
```

Now we will define bridge `public` and attach it to our `re0` network interface
(bridge allows attaching virtual machines to our main interface - similar to
default Proxmox VE setup) - try `man vm` to see details:

```shell
vm switch create public
# replace 're0' with your network card name:
vm switch add public re0
vm switch list

  NAME    TYPE      IFACE      ADDRESS  PRIVATE  MTU  VLAN  PORTS
  public  standard  vm-public  -        no       -    -     re0
```

# Create first VM

I will first follow `man vm` and create FreeBSD 13 guest (my intention to clearly
distinguish my guest (FreeBSD 13) and Host (FreeBSD 14.3):

First I visited this page using:
```shell
lynx https://download.FreeBSD.org/releases/amd64/amd64/ISO-IMAGES/13.5/
```

To get Download URL for uncompressed disc1 image:

> WARNING! It seems that `vm` script does not support compressed image download (yet).

```shell
vm iso https://download.FreeBSD.org/releases/amd64/amd64/ISO-IMAGES/13.5/FreeBSD-13.5-RELEASE-amd64-disc1.iso
```

Before creating VM we need to verify used template:
- at `vm-bhyve` setup time following template is copied:
  `/usr/local/share/examples/vm-bhyve/default.conf` (plain FreeBSD template
  using direct loader `bhyveload`).
- such template is than found under `POOL/DATASET/.templates`
- in my case:

```shell
$ vm datastore list

NAME            TYPE        PATH                      ZFS DATASET
default         zfs         /zroot/vm-bhyve           cbsd/vm-bhyve

### notice PATH: /zroot/vm-bhyve

$ cat /zroot/vm-bhyve/.templates/default.conf

loader="bhyveload"
cpu=1
memory=256M
network0_type="virtio-net"
network0_switch="public"
disk0_type="virtio-blk"
disk0_name="disk0.img"
```

Now we will install first `FreeBSD 13` guest using (from `man vm`):

```shell
vm create fbsd13-vm1
# find iso name:
ls -l /zroot/vm-bhyve/.iso/
vm install -f fbsd13-vm1 FreeBSD-13.5-RELEASE-amd64-disc1.iso
```

* WARNING! Anytime VM is started or stopped the bridge briefly halts
  network for few seconds on main interface (it is somehow related to adding
  and removing `tap(4)` interface for VM). I read note about
  it somewhere but forgot source. I will later resolve this problem
  using NAT network
* NOTE: you may need to press ENTER to see console output
* when FreeBSD asks you for console type, you can use `xterm` if running
  under `xterm` or `tmux` to get color output (default `vt100` is
  black and white only and without resize)
* NOTE: to exit console after install press `~.` (tilde followed
  by dot) - if it will not react try `ENTER` followed by `~.`
  Manual also supports Ctrl-D but it did not work in my case

After install you should use different command - `start` instead
of `install`

```shell
$ vm list

NAME        DATASTORE  LOADER     CPU  MEMORY  VNC  AUTO  STATE
fbsd13-vm1  default    bhyveload  1    256M    -    No    Stopped

$ vm start -f fbsd13-vm1
```

Important configuration files - all are relative to `PATH` in:

```shell
$ vm datastore list

NAME            TYPE        PATH                      ZFS DATASET
default         zfs         /zroot/vm-bhyve           cbsd/vm-bhyve
```

So in my case:

- system config: `/zroot/vm-bhyve/.config/system.conf`
- default template: `/zroot/vm-bhyve/.templates/default.conf`
- VM config: `/zroot/vm-bhyve/fbsd13-vm1/fbsd13-vm1.conf`

You can see them on my Git repo under [cubi-nvme/zroot/vm-bhyve](cubi-nvme/zroot/vm-bhyve)

# Tesing Alpine guest

Now we will try to install Alpine Linux guest using `grub-bhyve` loader (GRUB that runs
on FreeBSD Host to load Linux kernel and ramdisk to memory and then jumping directly to
bhyve to run preloaded VM).

First we have to download ISO:
- visit https://www.alpinelinux.org/downloads/
- note URL of "Virtual" flavor image: https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-virt-3.22.0-x86_64.iso


Run:
```shell
vm iso https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-virt-3.22.0-x86_64.iso
```

Now we will create VM using ready-made
template `/usr/local/share/examples/vm-bhyve/alpine.conf`

```shell
# first we have to copy template if it is not there:
cp /usr/local/share/examples/vm-bhyve/alpine.conf /zroot/vm-bhyve/.templates/
# yes, Alpine Linux will install fine on 1GB disk!
vm create -t alpine -s 1G alpine1
```

NOTE: VM memory size copied from template file - if want to change it you can
directly edit later `/zroot/vm-bhyve/alpine1/alpine1.conf`

Now try installation:
```shell
vm install alpine1 alpine-virt-3.22.0-x86_64.iso
vm console alpine1
```

Err, after pressing ENTER you will find that GRUB is not happy:
```
alpine-virt-3.22.0-x86_64.isoerror: file `/boot/vmlinuz-vanilla' not found.
error: you need to load the kernel first.
```
We can press `c` and investiage:
```
grub> ls (cd0)/boot
config-6.12.31-0-virt dtbs-virt/ grub/ initramfs-virt modloop-virt syslinux/ Sy
stem.map-6.12.31-0-virt vmlinuz-virt
```

Aha! We have to specify `vmlinuz-virt` insted of `vmlinuz-vanilla`.
One solution is to
- press "ESC" and wait for  main menu
- press `e` to edit and change `vmlinuz-vanilla` to `vmlinuz-virt`
- WARNING! You may NOT use cursor keys - must use EMACS shortcuts (`Ctrl`-`a` for Home,
  `Ctrl`-`e` for End, `Ctrl`-`n` for Down, `Ctrl`-`p` for Up, Ctrl-`f` for Right).
- press `Ctrl`-`x` to boot

It should boot successfully then you have to:
- login as `root` without password
- run `setup-alpine`
- when asked for `Which disks...` answer `vda` (KVM Virtio-BLK device emulated by Bhyve).
- `How use it...` - type `sys`
- confirm Erase
- run `poweroff` to shutdown
- press `ENTER` and `~.` to exit console

Now tricky stuff - running VM
- we will try `vm start alpine1` and `vm console alpine1`
- but get:

```
   Booting `alpine1 (bhyve run)'

error: unknown filesystem.
error: you need to load the kernel first.
```

Yes, it is problem with incompatible `ext4` features
- note: to exit GRUB use `c` to get command line and `reboot` command
- again use `ENTER` followed by `~.` to exit console

Now we will fix it same way as in our [README.md](README.md):

```shell
$ mdconfig /zroot/vm-bhyve/alpine1/disk0.img

md0

$ gpart show md0
=>     63  2097089  md0  MBR  (1.0G)
       63     1985       - free -  (993K)
     2048   614400    1  linux-data  [active]  (300M)
   616448   524288    2  linux-swap  (256M)
  1140736   956416    3  linux-data  (467M)

$ pkg install e2fsprogs-core             # provides tune2fs
$ tune2fs -l /dev/md0s1 | grep features

Filesystem features:      has_journal ext_attr resize_inode \
  dir_index orphan_file filetype extent flex_bg metadata_csum_seed \
  sparse_super large_file huge_file dir_nlink extra_isize metadata_csum

# found empiricaly by comparing with working Debian 12 machine:

$ tune2fs -O ^orphan_file,^metadata_csum_seed /dev/md0s1

# unbind .raw file from md0

$ mdconfig -du md0
```

And booting again...

Again - issue - grub expects `vmlinuz-vanilla` but we use `vmlinuz-virt`
As temporary measure we can again press `e` and change kernel and initramdisk
names to boot (see above text).

Final fix: simply rename all `vanilla` to `virt` in configuration
file of VM - in my case `/zroot/vm-bhyve/alpine1/alpine1.conf` - it will
fix them forever.

