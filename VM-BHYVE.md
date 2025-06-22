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
lynx https://download.FreeBSD.org/releases/amd64/amd64/ISO-IMAGES/14.3/
```

To get Download URL for uncompressed disc1 image:

> WARNING! It seems that `vm` script does not support compressed image download (yet).

```shell
vm iso https://download.FreeBSD.org/releases/amd64/amd64/ISO-IMAGES/14.3/FreeBSD-14.3-RELEASE-amd64-disc1.iso
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
vm install fbsd13-vm1 FreeBSD-14.3-RELEASE-amd64-disc1.iso
vm console fbsd13-vm1
```

* NOTE: you may need to press ENTER to see console output
* NOTE: to exit console after install press `~.` (tilde followed
  by dot) - if it will not react try `ENTER` followed by `~.`
  Manual also supports Ctrl-D but it did not work in my case

After install you should use different command - `start` instead
of `install`

```shell
$ vm list

NAME        DATASTORE  LOADER     CPU  MEMORY  VNC  AUTO  STATE
fbsd13-vm1  default    bhyveload  1    256M    -    No    Stopped   

$ vm start fbsd13-vm1
$ vm console fbsd13-vm1
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


