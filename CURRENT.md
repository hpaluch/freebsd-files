# Using FreeBSD current

Here is my guide how to use FreeBSD current from "scratch" (from CURRENT ISO)

Starting with download on: Tue, 12 Aug 2025
- page: https://download.freebsd.org/snapshots/amd64/amd64/ISO-IMAGES/15.0/
- or select mirror from https://docs.freebsd.org/en/books/handbook/mirrors/#mirrors
- command:
  ```shell
  curl -fLO https://download.freebsd.org/snapshots/amd64/amd64/ISO-IMAGES/15.0/FreeBSD-15.0-CURRENT-amd64-20250807-02f394281fd6-279407-disc1.iso.xz
  # or user rather mirror, in my case:
  curl -fLO http://ftp.cz.freebsd.org/pub/FreeBSD/snapshots/ISO-IMAGES/15.0/FreeBSD-15.0-CURRENT-amd64-20250807-02f394281fd6-279407-disc1.iso.xz
  ```
- unpack, but keep compressed file:
  ```shell
  xz -dkv FreeBSD-15.0-CURRENT-amd64-20250807-02f394281fd6-279407-disc1.iso.xz
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
> binary packages because they sometimes lag several weeks (!).
> There is lengthy discussion of such occasion starting on:
> - https://marc.info/?l=freebsd-current&m=175489043024606&w=2
> - click on `next-in-thread` link to see follow-ups
> Or my bug report:
> - details: https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=288650
>
> So we should build everything from Ports collection sources when running CURRENT.

We have to build and install at least these packages to be able to update
pre-installed sources to latest latest Git version:

- `perl` - some tasks (`make index`) require PERL
- `git-lite` - we need git to checkout/pool latest FreeBSD version from repository, under
  hood it requires `curl` (for https) and `expat` (for https push - posts XML?) and 
  several other ports to build and run.

Recommended: backup original content of `/usr/src` and `/usr/ports`.
If you have standard `AutoZFS` layout from installation, you can use:

```shell
# run
for mnt in /usr/src /usr/ports;do ds=`mount | awk -v mnt="$mnt" '$3 == mnt { print $1}'`;zfs snapshot $ds@orig-sources;done

# verification:

for mnt in /usr/src /usr/ports;do ds=`mount | awk -v mnt="$mnt" '$3 == mnt { print $1}'`;zfs list -t all -r $ds;done

  NAME                          USED  AVAIL  REFER  MOUNTPOINT
  znext4/usr/src                922M  34.1G   922M  /usr/src
  znext4/usr/src@orig-sources     0B      -   922M  -
  NAME                            USED  AVAIL  REFER  MOUNTPOINT
  znext4/usr/ports                862M  34.1G   862M  /usr/ports
  znext4/usr/ports@orig-sources     0B      -   862M  -
```

Note: With ZFS you can easily see what changed in your sources, example for ports:

```shell
zfs diff znext4/usr/ports@orig-sources
```

Recommended: create dedicated dataset for `/usr/obj` - so we can quickly clean it with
just rollback of snapshot:

```shell
root_ds=$( zfs list -H / | awk '{ print $1}' | sed 's@/.*@@' )
echo "'$root_ds'"

  'znext4'

zfs create -o mountpoint=/usr/obj -o canmount=on $root_ds/usr/obj
zfs snapshot $root_ds/usr/obj@empty
zfs list -rt all /usr/obj

  NAME                   USED  AVAIL  REFER  MOUNTPOINT
  znext4/usr/obj          96K  34.1G    96K  /usr/obj
  znext4/usr/obj@empty     0B      -    96K  -
```

Recommended: create new Boot Environment so we can rollback
to clean system (including `/` `/usr` and `/usr/local` with default ZFS layout):

```shell
bectl create pristine
bectl list

  BE       Active Mountpoint Space Created
  default  NR     /          460M  2025-08-12 16:59
  pristine -      -          8K    2025-08-12 17:05
```

Before building any port we will prepare default configuration for several Ports.
Create file `/etc/make.conf` with contents:

```make
OPTIONS_UNSET_FORCE=DOCS EXAMPLES NLS INFO BASH ZSH

# from: https://forums.freebsd.org/threads/flavors-and-make-install.79525/
# activate FLAVOR=tiny when building Git from ports:
.if ${.CURDIR:C/.*\/devel\/git//} == ""
FLAVOR=tiny
.endif

# git requires ftp/curl - remove most bloat:
ftp_curl_UNSET = ALTSVC IDN IPV6 NTLM PSL STATIC TLS_SRP DICT GOPHER HTTP2 IMAP IPFS \
  LIBSSH2 MQTT POP3 RTSP SMB SMTP TELNET TFTP WEBSOCKET GSSAPI_NONE

DEFAULT_VERSIONS+=perl5=5.40
# deselect all default options in perl5.40
lang_perl5.40_UNSET = DTRACE MULTIPLICITY PERL_64BITINT THREADS
```

First we will build PERL that is required to invoke `make index`:
```shell
cd /usr/ports/lang/perl5.40
make install # will first build portconfig and pkg
# on configuration dialog simply press ENTER to accept defaults (all unchecked)
```

Now build Ports index (requires `perl` to finish without error) - may take around 30 minutes:

```shell
time make -C /usr/ports index

# 23 minutes on 8 cores
```

Index seems to improve dependency handling (?) - without it I got extremely big bloat when
building curl - which has `expat2` dependency.

Now we will build `portmaster` - preferred tool to manage ports:

```shell
make -C /usr/ports/ports-mgmt/portmaster install
```

Recommended - build `tmux` to reduce risk that broken connection will abort
future builds:

```shell
portmaster -i sysutils/tmux
# tmux: press ENTER to accept config
# libevent: uncheck all checkboxes with SPACE and press ENTER

===>>> The following actions will be taken if you choose to proceed:
	Install sysutils/tmux
	Install devel/libevent
	Install devel/pkgconf
```

Now 

- create `~/.tmux.conf` with vivid color (to know where I'm logged in) - example for deep blue:

  ```
  set-option -g status-style bg='#000080'
  ```

- run `tmux` (to avoid broken connection)
- and finally build `git-lite` with:

```shell
portmaster -i devel/git

# I did following when asked for port options:
# m4 config: press ENTER to accept defaults (all unchecked)
# curl config: press ENTER to accept defaults (few checked)
# brotli: press ENTER to accept default (unchecked)
# python: uncheck all (IPV6 LIBMPDEDC LTO PYMALLOC) and ENTER
# readline: uncheck BRACKETEDPASTE and press ENTER
# libiconv: press ENTER to accept defaults (checked ENCODINGS)
# expat: press ENTER to accept defaults (all unchecked)
# zstd: press ENTER to accept defaults (unchecked)
# liblz4: press ENTER to accept defaults

# Here is final postmaster's list of packages to be build for devel/git:
===>>> The following actions will be taken if you choose to proceed:                                                                                
        Install devel/git                                                                                                                           
        Install devel/autoconf                                            
        Install devel/autoconf-switch         
        Install devel/m4
        Install devel/automake
        Install print/indexinfo
        Install devel/gmake
        Install ftp/curl
        Install archivers/brotli
        Install devel/cmake-core
        Install devel/jsoncpp
        Install devel/meson
        Install devel/ninja
        Install lang/python311
        Install devel/libffi
        Install devel/readline
        Install devel/py-build@py311
        Install devel/py-flit-core@py311
        Install devel/py-installer@py311
        Install devel/py-packaging@py311
        Install devel/py-pyproject-hooks@py311
        Install devel/py-setuptools@py311
        Install devel/py-wheel044@py311
        Install devel/py-wheel@py311
        Install devel/libuv
        Install dns/libidn2
        Install devel/libunistring
        Install misc/help2man
        Install print/texinfo
        Install converters/libiconv
        Install converters/p5-Text-Unidecode
        Install devel/p5-Locale-libintl
        Install textproc/p5-Unicode-EastAsianWidth
        Install security/rhash
        Install textproc/expat2
        Install archivers/zstd
        Install archivers/liblz4

===>>> Proceed? y/n [y] 

(sorry, forget to run "time" - guess is 30 minutes on 8 cores)
```

Now verify that git really works with https (`clone/pull/fetch` over https is enough for us):

```shell
# my FreeBSD repo (it is significantly smaller than 'src' or 'ports')
git clone https://github.com/hpaluch/freebsd-files.git ~/test-freebsd-files
# should finish without error.
```

# Updating sources

> WARNING! After source updates your system will be inconsistent:
> - binaries match original sources from ISO installation
> - but source code in `/usr/src` and in `/usr/ports` will be ahead
> After updating sources we will have to build and update system.

So, finally we can proceed to update `/usr/src` and `/usr/ports` to latest CURRENT versions from Git repositories:

For `/usr/src`:
```shell
cd /usr/src
git init
git remote add origin https://git.FreeBSD.org/src.git
git fetch origin
git clean -fdx # remove all existing files, keep just .git
git checkout -t origin/main
git branch -v

  * main a39277782140 libc: Fix style nits in flushlbuf regression test
```

For `/usr/ports`:
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

NOTE: In my case I actually copied tarballs from another machine (with latest Git sources) to
avoid overloading FreeBSD.org Git servers.

- I prepared source tarballs on source machine with:

  ```shell
  cd /
  tar -cvzf /home/ansible/tarballs/usr-src-latest.tar.gz usr/src
  tar -cvzf /home/ansible/tarballs/usr-ports-latest.tar.gz usr/ports
  ```

- on my Target machine I did this - warning destructive delete
- NEVER use `rm -rf .*` - it WILL match `..` parent directories (unless special glob options are set) and remove everything !
- see https://unix.stackexchange.com/a/77128 

  ```shell
  cd
  find /usr/src -mindepth 1 -delete
  tar xpvf /home/ansible/tarballs/usr-src-latest.tar.gz -C /
  find /usr/ports -mindepth 1 -delete
  tar xpvf /home/ansible/tarballs/usr-ports-latest.tar.gz  -C /
  ```

- here are details on Git repository versions ( Aug 12, 2025 ):

  ```shell
  git -C /usr/src branch -v

    * main 4a94dee2a497 ObsoleteFiles: both gssapi/gssapi.h and gssapi.h existed

  git -C /usr/ports branch -v

    * main 3bb58a295d37 dns/dnsmasq-devel: update to v2.92test19
  ```

- or other way, but often confusing:

  ```shell
  git -C /usr/src describe  --long --always

    vendor/NetBSD/bmake/20250804-302018-g4a94dee2a497

  git -C /usr/ports describe  --long --always

    13.4-eol-3819-g3bb58a295d37
  ```

# Updating system (world)

We will first do thing that should do NOT modify system (so generally no backup
needed yet - but it will not hurt of course).

We will invoke following `make` targets:
- `buildworld` - userland (system)
- `buildkernel` - OS Kernel

Please note that `buildworld` takes lot of time (hours) because it will build
toolchain - `clang+llvm`. Here is toolchain version *before* build:

```shell
cc --version | sed 1q

  FreeBSD clang version 19.1.7 (https://github.com/llvm/llvm-project.git llvmorg-19.1.7-0-gcd708029e0b2)
```

To build World and Kernel do this:
```shell
tmux # use tmux or local console - build will take lot of time!

script ~/build-world-$(date '+%s').log
cd /usr/src
time make -j`nproc` buildworld
time make -j`nproc` buildkernel
```

Build statistics:
```
TODO
```

Now you should definitely backup system, at least with `bectl`:
```shell
bectl create buildworld
bectl list

TODO
```

Note your current kernel and userland versions (soon will be different):
```shell
$ uname -v

FreeBSD 15.0-CURRENT #0 main-n279407-02f394281fd6: Thu Aug  7 11:11:50 UTC 2025 \
     root@releng3.nyi.freebsd.org:/usr/obj/usr/src/amd64.amd64/sys/GENERIC

$ uname -UK # print both Userland and Kernel version:

1500056 1500056
```

So far they are same (so there is no confusion which number is Kernel and which number is Userland).

For updating main system we should generally follow:
- https://docs.freebsd.org/en/books/handbook/cutting-edge/#updating-src-quick-start
- also read latest `/usr/src/UPDATING` including end section `COMMON ITEMS:`
- NOTE: sometimes there should be build custom toolchain for kernel - see UPDATING for details.

Now we will install prepared kernel and reboot:
```shell
cd /usr/src
make -j`nproc` installkernel
```

WARNING! After reboot we will run Kernel that is More recent than World (system).
It sometimes causes malfunction - for example `ipfw` broken (so firewall will be blocked).
Before reboot ensure that you have Console access so you can fix broken network.

Now boot new kernel and prepare `/etc/` for changes (-p) means "pre-world":
```shell
reboot
etcupdate -p
```

Now we will install system (World) - most risky but important! Only after
following steps your System will again match Kernel version and should fully work
again:

```shell
cd /usr/src
make installworld
etcupdate -B # I don't understand what -B exactly does...
reboot
```

Here is system status on Aug 7, 2025:

```shell
# freebsd-version

15.0-CURRENT

# uname -a

FreeBSD fbsd-next3 15.0-CURRENT FreeBSD 15.0-CURRENT #0 main-n279420-a39277782140: \
   Thu Aug  7 19:36:21 CEST 2025     root@fbsd-next3:/usr/obj/usr/src/amd64.amd64/sys/GENERIC amd64
# uname -U

1500056

# uname -K

1500056

# cd /usr/src/
# git branch -vv

* main a39277782140 [origin/main] libc: Fix style nits in flushlbuf regression test

```

# Updating to latest ports

Following: https://docs.freebsd.org/en/books/handbook/ports/#portmaster

```shell
cd /usr/ports/ports-mgmt/portmaster
make install clean
portmaster -L
# do update
time portmaster -a
```

Here is output:

```
===>>> The following actions were performed:
	Upgrade of pkg-2.2.0 to pkg-2.2.2
	Upgrade of bsddialog-1.0.4 to bsddialog-1.0.5
	Upgrade of expat-2.7.0 to expat-2.7.1
	Upgrade of pkgconf-2.3.0,1 to pkgconf-2.4.3,1
	Upgrade of portconfig-0.6.2 to portconfig-0.6.2_1
	Upgrade of perl5-5.40.2 to perl5-5.40.2_2
	Upgrade of curl-8.14.1 to curl-8.15.0
	Upgrade of libffi-3.4.6 to libffi-3.5.1
	Upgrade of python311-3.11.12_1 to python311-3.11.13
	Upgrade of py311-flit-core-3.11.0 to py311-flit-core-3.12.0
	Upgrade of py311-packaging-24.2 to py311-packaging-25.0
	Upgrade of git-tiny-2.49.0 to git-tiny-2.50.1
	Installation of devel/py-wheel044@py311 (py311-wheel044-0.44.0_1)
	Upgrade of py311-setuptools-63.1.0_2 to py311-setuptools-63.1.0_3
	Upgrade of texinfo-7.1_8,1 to texinfo-7.1_11,1

      748.15 real      1890.19 user       268.38 sys
```

TODO: Rebuild all ports:
- when there is new system library changes we (may) need to rebuild all installed ports
- described at the end of `portmaster(8)` manual:
- https://man.freebsd.org/cgi/man.cgi?query=portmaster&apropos=0&sektion=8&manpath=freebsd-ports&format=html
- original discussion: https://forums.freebsd.org/threads/rebuilding-all-ports-with-portmaster.51210/


