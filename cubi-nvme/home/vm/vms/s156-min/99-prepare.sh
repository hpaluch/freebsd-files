#!/bin/sh
set -xeuo pipefail

qcow2=openSUSE-Leap-15.6-Minimal-VM.x86_64-15.6.0-kvm-and-xen-Build16.32.qcow2
raw=leap156-min.raw
exp_type='QEMU QCOW Image'

cd "$(dirname "$0")"

[ -f "$qcow2" ] || curl -fLO https://ftp.linux.cz/pub/linux/opensuse/distribution/leap/15.6/appliances/$qcow2
file "$qcow2" | grep "$exp_type" || {
	echo "ERROR: Downloaded file '$qcow2' is not '$exp_type'" >&2
	exit 1
}
[ -f "$raw" ] || qemu-img convert -p -f qcow2 -O raw $qcow2 $raw
exit 0
