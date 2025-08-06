# Using FreeBSD current

Here is my guide how to use FreeBSD current from "scratch" (from CURRENT ISO)

Starting with download on: Tue, 05 Aug 2025
- page: https://download.freebsd.org/snapshots/amd64/amd64/ISO-IMAGES/15.0/
- command:
  ```shell
  curl -fLO https://download.freebsd.org/snapshots/amd64/amd64/ISO-IMAGES/15.0/FreeBSD-15.0-CURRENT-amd64-20250801-0a3792d5c576-279199-disc1.iso.xz
  ```
- unpack, but keep compressed file:
  ```shell
  xz -dkv FreeBSD-15.0-CURRENT-amd64-20250801-0a3792d5c576-279199-disc1.iso.xz
  ```

Using VM under KVM:
- 40GB disk
- CPUs and memory: as much as possible
- system layout: "Traditional"
- distribution sets: `ports` and `src`
- partitioning: `AutoZFS`
- scheme: `GPT (BIOS+UEFI)` = hybrid
- Network configuration:
  - be sure to choose `Manual`, otherwise it will
    try to configure IPv6 (which will timeout on my VM)
  - you can still select DHCP + IPv4 only


# Building perl+git to update sources

> I found hard way that CURRENT from ISO is generally incompatible with
> binary packages.
>
> - details: https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=288650
>
> So we should build everything from Ports collection sources.
> And NEVER install binary packages on CURRENT because they lag too much
> and often reference library versions that no longer exist in World
> (base system).

We have to build and install at least these packages to be able to update
preinstalled sources to latest latest Git version:
- `perl` - some tasks (`make index`) require PERL
- `git-lite` - we need git to checkout/pool latest FreeBSD version from repository

Recommended: backup original content of `/usr/src` and `/usr/ports`.
If you have standard `AutoZFS` layout from installation, you can use:
```shell
# dry run (notice "echo"):
for mnt in /usr/src /usr/ports;do ds=`mount | awk -v mnt="$mnt" '$3 == mnt { print $1}'`;echo zfs snapshot $ds@orig-sources;done

  zfs snapshot zroot/usr/src@orig-sources
  zfs snapshot zroot/usr/ports@orig-sources

# real run:

for mnt in /usr/src /usr/ports;do ds=`mount | awk -v mnt="$mnt" '$3 == mnt { print $1}'`;zfs snapshot $ds@orig-sources;done

# verification:

for mnt in /usr/src /usr/ports;do ds=`mount | awk -v mnt="$mnt" '$3 == mnt { print $1}'`;zfs list -t all -r $ds;done

  NAME                         USED  AVAIL  REFER  MOUNTPOINT
  zroot/usr/src                916M  33.9G   916M  /usr/src
  zroot/usr/src@orig-sources     0B      -   916M  -
  NAME                           USED  AVAIL  REFER  MOUNTPOINT
  zroot/usr/ports                842M  33.9G   842M  /usr/ports
  zroot/usr/ports@orig-sources     0B      -   842M  -
```

Note: With ZFS you can easily see what changed in your sources, example for ports:

```shell
zfs diff zroot/usr/ports@orig-sources
```

Recommended: create dedicated dataset for `/usr/obj` - so we can quickly clean it with
just revert snapshot:

```shell
root_ds=$( zfs list -H / | awk '{ print $1}' | sed 's@/.*@@' )
echo "'$root_ds'"

  'znext3'

zfs create -o mountpoint=/usr/obj -o canmount=on $root_ds/usr/obj
zfs snapshot $root_ds/usr/obj@empty
zfs list -rt all /usr/obj

  NAME                   USED  AVAIL  REFER  MOUNTPOINT
  znext3/usr/obj          96K  39.0G    96K  /usr/obj
  znext3/usr/obj@empty     0B      -    96K  -
```


Recommended: create new Boot Environment so we can rollback
to clean system (including `/` `/usr` and `/usr/local` with default ZFS layout):

```shell
bectl create current1
bectl activate current1
# and reboot to "current1" BE:
reboot
```

After reboot we can verify that our current BE is now `current1`, while
`default` is original installation from ISO.

```shell
$ bectl list

BE       Active Mountpoint Space Created
current1 NR     /          460M  2025-08-06 16:44
default  -      -          492K  2025-08-06 16:32
```

Now we will try to build PERL:
- first we must pin PERL version (it was also mentioned in /usr/ports/UPDATING in past):

  ```shell
  # required - pin PERL version temporarily:
  echo 'DEFAULT_VERSIONS+=perl5=5.40' >> /etc/make.conf
  ```

- disable typical bloat:

  ```shell
  echo 'OPTIONS_UNSET_FORCE=DOCS EXAMPLES NLS INFO' >> /etc/make.conf
  ```

- now we can build it - notice which version you should build from above command:

WARNING! I will evaluate dependencies one by one - it is hard job, but only
way to avoid excessive dependency bloat...

```shell
cd /usr/ports/lang/perl5.40
make config # uncheck all

make build-depends-list

  /usr/ports/ports-mgmt/pkg

cd /usr/ports/ports-mgmt/pkg
make build-depends-list # should be empty
make install # or make reinstall if you already did that

# now back to perl - should build PERL only:
cd /usr/ports/lang/perl5.40
make install
```

- now we can build Ports index (requires PERL):

```shell
cd /usr/ports
time make index

1368.50 real
```

- yes it took around 22 minutes...
- with index we can use `pretty-print-build-depends-list, pretty-print-run-depends-list` make targets,
- now we need working `curl` (will be used for `git` as `libcurl`):

```shell
cd /usr/ports/ftp/curl
make config

# keep just COOKIES, PROXY, STATIC, HTTP
# set GSSAPI_NON
# keep THRADED_RESOLVER and OPENSSL

make build-depends-list

  /usr/ports/ports-mgmt/pkg
  /usr/ports/lang/perl5.40

make all-depends-list

  /usr/ports/ports-mgmt/pkg
  /usr/ports/lang/perl5.40

# looks good, install:
make install
```

Final frontier - git
- starting with: https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=288650#c6
- create file `/etc/make.conf` with contents:

```make
# from: https://forums.freebsd.org/threads/flavors-and-make-install.79525/
# activate FLAVOR=tiny when building Git from ports:
.if ${.CURDIR:C/.*\/devel\/git//} == ""
FLAVOR=tiny
.endif
```

Your full `/etc/make.conf` should look like:

```make
DEFAULT_VERSIONS+=perl5=5.40
OPTIONS_UNSET_FORCE=DOCS EXAMPLES NLS INFO
# from: https://forums.freebsd.org/threads/flavors-and-make-install.79525/
# activate FLAVOR=tiny when building Git from ports:
.if ${.CURDIR:C/.*\/devel\/git//} == ""
FLAVOR=tiny
.endif
```

Now building git that must use our port version of `libcurl`:
```shell
cd /usr/ports/devel/git
make build-depends-list
```

Problem: `textproc/expat2` brings unbelievable amount of dependencies.
So comment it out in Makefile:

```diff
 diff  Makefile.orig Makefile
124c124
< CURL_LIB_DEPENDS=	libexpat.so:textproc/expat2
---
> #CURL_LIB_DEPENDS=	libexpat.so:textproc/expat2
```


```shell
# now it is a bit better:

make all-depends-list

  /usr/ports/ports-mgmt/pkg
  /usr/ports/ftp/curl
  /usr/ports/lang/perl5.40
  /usr/ports/devel/gmake
  /usr/ports/print/indexinfo
  /usr/ports/converters/libiconv
  /usr/ports/devel/autoconf
  /usr/ports/devel/m4
  /usr/ports/devel/autoconf-switch
  /usr/ports/devel/automake
  
# so let's build:
time make instal
# m4: keep all unchecked

# took: 134.15 real
```
Now verify that git really works with https:
```shell
git clone https://github.com/hpaluch/freebsd-files.git ~/test-freebsd-files
# should finish without error.
```

# Updating sources

> WARNING! After source updates our system will be inconsistent:
> - binaries matching original sources from ISO installation
> - but source code in /usr/src and in /usr/ports will be ahead
> After updating sources we will have to update system.

Finally we can proceed to update `/usr/src` and `/usr/ports` to latest CURRENT versions from Git repositories:

For /usr/src:
```shell
cd /usr/src
git init
git remote add origin https://git.FreeBSD.org/src.git
git fetch origin
git clean -fdx # remove all existing files, keep just .git
git checkout -t origin/main
git branch -v

  * main 9a726ef24134 krb5: Move compile_et to /usr/bin as it was with Heimdal
```

For /usr/ports:
```shell
cd /usr/ports
git init
git remote add origin https://git.FreeBSD.org/ports.git
git fetch origin
git clean -fdx # remove all existing files, keep just .git
git checkout -t origin/main
git branch -v

  * main 5c916ccc133f security/pinentry: Update to 1.3.2
```

# Updating system (world)

We will do in-place upgrade (world install) which is always risky.

This kind of build is described on `build(7)` manual page.

> Possible alternative:
> - rather create fresh ISO image and install it somewhere (like T2SDE Linux)
> - not yet tested, but planed... - some info in `release(7)`

For updating main system we should generally follow:
- https://docs.freebsd.org/en/books/handbook/cutting-edge/#updating-src-quick-start

```shell
# already did that:
git -C /usr/src pull
less /usr/src/UPDATING

# make snapshot of current Boot Environemt (BE)

$ bectl list

BE      Active Mountpoint Space Created
default NR     /          2.03G 2025-08-05 16:53

$ bectl create -r default@origworld
$ bectl list -s

BE/Dataset/Snapshot  Active Mountpoint Space Created

default
  zroot/ROOT/default NR     /          2.03G 2025-08-05 16:53
  default@origworld  -      -          0     2025-08-05 19:21

# It looks weird, but snapshot looks fine:
zfs list -t snap
NAME                           USED  AVAIL  REFER  MOUNTPOINT
zroot/ROOT/default@origworld   256K      -  2.03G  -
zroot/usr/ports@orig-sources   842M      -   842M  -
zroot/usr/src@orig-sources     916M      -   916M  -
```

> WARNING! `bectl create NEW_ENV_NAME` work in 3 steps:
> 
> 1. create "Snapshot" from current Environment
> 2. make New Environment as "Clone" from created "Snapshot"
> 3. Promote that clone - swaps parent/child relationship.
> 
> It is reason, why when you look to dataset/snapshot relationship, it
> is reversed - thanks to step 3...

Second, I was confused by bectl snapshots but found this important note
in `man bectl`:

> In that example, zroot/usr has canmount set to off, thus files in /usr
> typically fall into the boot environment because this dataset is not
> mounted.  zroot/usr/src is mounted, thus files in /usr/src are not in the
> boot environment.

In my case there is:
```shell
$ zfs list -o name,canmount,mountpoint

NAME                CANMOUNT  MOUNTPOINT
zroot               on        /zroot
zroot/ROOT          on        none
zroot/ROOT/default  noauto    /
zroot/home          on        /home
zroot/home/ansible  on        /home/ansible
zroot/tmp           on        /tmp
zroot/usr           off       /usr
zroot/usr/ports     on        /usr/ports
zroot/usr/src       on        /usr/src              
zroot/var           off       /var                                        
zroot/var/audit     on        /var/audit                        
zroot/var/crash     on        /var/crash
zroot/var/log       on        /var/log
zroot/var/mail      on        /var/mail
zroot/var/tmp       on        /var/tmp
```

What really confused me, is that there is shown `/usr` under `MOUNTPOINT` - that
it it  bogus when `CANMOUNT=off`. It seems that `df` shows what is
really mounted:

```shell
$ df -h

Filesystem            Size    Used   Avail Capacity  Mounted on
zroot/ROOT/default     29G    6.1G     23G    21%    /
devfs                 1.0K      0B    1.0K     0%    /dev
/dev/gpt/efiboot0     260M    1.3M    259M     1%    /boot/efi
zroot/home             23G     96K     23G     0%    /home
zroot/tmp              23G    380K     23G     0%    /tmp
zroot/var/log          23G    164K     23G     0%    /var/log
zroot/var/audit        23G     96K     23G     0%    /var/audit
zroot/var/crash        23G     96K     23G     0%    /var/crash
zroot/usr/ports        26G    2.4G     23G     9%    /usr/ports
zroot/var/tmp          23G     96K     23G     0%    /var/tmp
zroot                  23G     96K     23G     0%    /zroot
zroot/var/mail         23G    144K     23G     0%    /var/mail
zroot/usr/src          26G    2.7G     23G    10%    /usr/src
zroot/home/ansible     23G    452K     23G     0%    /home/ansible
```

Here we see that `/usr` is not mounted so it should really belong to BE (
and USED column is definitely increasing for `zroot/ROOT/default`).

So conclusion:
- `bectl` boot backup should cover also `/usr`  (without `/usr/src` and/or `/usr/ports`
  as can be seen on `df` output).
- `zfs list -o ...,mountpoint` output is not relevant if `canmount=off`


To build userland we have to invoke:

```shell
cd /usr/src
time make -j`nproc` buildworld
```

Here are stats (using VM with 6 cores):

```
>>> World built in 9432 seconds, ncpu: 6, make -j6
```

Which is:
```shell
$ echo "Minutes: " $(( 9432 / 60 ))

Minutes:  157
```
So around 2.5 hours.


Up here there should be no change in system.

> BACKUP your data now!

TODO:

```shell
# resume installing and booting kernel:
make -j`nproc` kernel
shutdown -r now

etcupdate -p
cd /usr/src
make installworld
etcupdate -B
shutdown -r now
```


