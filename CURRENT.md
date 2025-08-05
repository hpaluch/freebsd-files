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


# Fixing git to update sources

WARNING! After reboot we have to follow special procedure
to install working `git` - see my bug for details:
- https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=288650

> But many things seem to changed with that new release.

First install some packages that do NOT conflict with curl/git and/or Kerberos:
```shell
pkg update
# WARNING! Ensure that no "curl" is installed (it has broken dependencies):
pkg install tmux vim
```

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

Now we can resume using my guide

- starting with: https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=288650#c6
- create file `/etc/make.conf` with contents:

  ```make
  # from: https://forums.freebsd.org/threads/flavors-and-make-install.79525/
  # activate FLAVOR=tiny when building Git from ports:
  .if ${.CURDIR:C/.*\/devel\/git//} == ""
  FLAVOR=tiny
  .endif
  ```

New problem: there is PERL version problem, because repository no longer contains expected version
- even `make index`  depends on perl so it is first thing we need to fix
- first verify that there is no perl at all so there is no library issue:
  ```shell
   which perl

  (no output)
  ```
- find latest perl version:
  ```shell
  $ ls -d /usr/ports/lang/perl*

  /usr/ports/lang/perl5-devel     /usr/ports/lang/perl5.36        /usr/ports/lang/perl5.38        /usr/ports/lang/perl5.40
  ```
- now trying:
  ```shell
  echo 'DEFAULT_VERSIONS+=  perl5=5.40' >> /etc/make.conf
  cd /usr/ports/lang/perl5.40
  make install
  # when asked, I unchecked all options
  ```
- now test if `make index` will finish without errors:
  ```shell
  cd /usr/ports
  make index
  # these are expected:
  #  make[4]: /usr/ports/Mk/bsd.port.mk:2036: warning: Invalid character " " in variable name "pkgconf --cflags libinotify"
  #
  # there may NOT be this error:
  #   /tmp/xxxx: perl not found
  ```

- build corrected `curl` (required for https support in git) however utilize as
  much binary packages as possible for quick build:

```shell
cd /usr/ports/ftp/curl

$ make build-depends-list

/usr/ports/ports-mgmt/pkg
/usr/ports/lang/perl5.40
/usr/ports/archivers/brotli
/usr/ports/archivers/zstd

# due multiple breakage we have to install packages manually:
# normally "make install-missing-packages" would do the trick...

pkg install brotli zstd
cd /usr/ports/ftp/curl
make install

# uncheck: ALTSVC, EXAMPLES, DOCS, IDN, IPV6 (if you don't need it)
#          NTLM, PSL, STATIC, TLS_SRP, DICT, GOPHER, HTTP2,
#          IMAP, IPFS, LIBSSH2, POP3, RTSP, SMTP, TELNET, WEBSOCKET, TFTP
# GSSAPI: select GSSAPI_NONE

# verify that curl really works:
curl -fsS https://www.freebsd.org/robots.txt
```


Now building git that must use our port version of `libcurl`:
```shell
cd /usr/ports/devel/git
make build-depends-list

/usr/ports/ports-mgmt/pkg
/usr/ports/ftp/curl
/usr/ports/devel/gmake
/usr/ports/devel/autoconf
/usr/ports/devel/automake
/usr/ports/textproc/expat2

# again we have to install manually:
pkg install gmake autoconf automake expat
# and build and install git:
make install
```

Now verify that git really works with https:
```shell
git clone --depth 1 --branch main https://git.FreeBSD.org/src.git ~/test-src
# should finish without error.
```

# Updating sources

> WARNING! After sources our system will be inconsistent:
> - binaries matching original sources from ISO installation
> - but source code in /usr/src and in /usr/ports is ahead
> After updating sources we will have to update system.

Finally we can proceed to update `/usr/src` and `/usr/ports` to latest CURRENT versions:

For /usr/src:
```shell
cd /usr/src
git init
git remote add origin https://git.FreeBSD.org/src.git
git fetch origin
git clean -fdx # remove all existing files, keep just .git
git checkout -t origin/main
```

For /usr/ports:
```shell
cd /usr/ports
git init
git remote add origin https://git.FreeBSD.org/ports.git
git fetch origin
git clean -fdx # remove all existing files, keep just .git
git checkout -t origin/main
```

We will rather build postmaster to have some kind of rescue tool:

- following: https://docs.freebsd.org/en/books/handbook/ports/#portmaster

```shell
cd /usr/ports/ports-mgmt/portmaster
make install clean
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

cd /usr/src          
time make -j`nproc` buildworld  
```

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


