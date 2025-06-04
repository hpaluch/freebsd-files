#!/bin/sh
set -euo pipefail

vm=t2-may2025
disk=/zroot/bhyve/images/$vm/$vm.raw
tap=tap0
mem_mb=8192

d="$(dirname "$0")"

echo "INFO: Using disk image '$disk'"
[ -f "$disk" ] || {
	echo "ERROR: image '$disk' is not a file" >&2
	exit 1
}

cd "$d"
echo 'WARNING! /boot on BTFS must have uncompressed files only!!!'
set -x
/usr/local/sbin/grub-bhyve -m device.map -r hd0,msdos2 -M $mem_mb $vm
echo "OK: Now running VM $vm"

bhyve -ADHP -c 6 -m $mem_mb \
	-s 0:0,hostbridge -s 1:0,lpc \
	-s 2:0,virtio-net,$tap \
	-s 3:0,virtio-blk,$disk \
	-l com1,stdio \
	$vm

# line below should not be needed (bhyve -D should do the trick)
bhyvectl --destroy --vm=$vm
exit 0
