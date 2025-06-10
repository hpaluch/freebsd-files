#!/bin/sh
set -euo pipefail

vm=leap156-min
disk=$vm.raw
tap=tap0
mem=2048

d="$(dirname "$0")"
disk="$d/$disk"

# doas if needed
sd=
[ `id -u` -eq 0 ] || sd='doas'

cleanup_vm()
{
	set +xe
	echo "Deleting VM '$vm'"
	$sd bhyvectl --destroy --vm=$vm
}

echo "INFO: Using disk image '$disk'"
[ -f "$disk" ] || {
	echo "ERROR: image '$disk' is not a file" >&2
	exit 1
}

cd "$d"
trap "cleanup_vm" EXIT
set -x
$sd /usr/local/sbin/grub-bhyve -m device.map -r 'hd0,gpt3' -d '/boot/grub2' -M $mem $vm
echo "OK: Now running VM $vm"

$sd bhyve -ADHP -c 1 -m $mem \
	-s 0:0,hostbridge -s 1:0,lpc \
	-s 2:0,virtio-net,$tap \
	-s 3:0,virtio-blk,$disk \
	-l com1,stdio \
	$vm
exit 0
