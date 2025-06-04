#!/bin/sh
set -euo pipefail
vm=trac-dr

cd $(dirname $0)
set -x
/usr/local/sbin/grub-bhyve -m device.map \
	-r 'hd0,msdos1' -d /grub \
	-M 1024 $vm
echo "OK: Now running VM $vm"

disk=/zroot/bhyve/images/$vm/$vm.raw
tap=tap0

bhyve -ADHP -c 1 -m 1024 \
	-s 0:0,hostbridge -s 1:0,lpc \
	-s 2:0,virtio-net,$tap \
	-s 3:0,virtio-blk,$disk \
	-l com1,stdio \
	$vm

# line below should not be needed (bhyve -D should do the trick)
bhyvectl --destroy --vm=$vm
exit 0
