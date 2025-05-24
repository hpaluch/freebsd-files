#!/bin/sh
set -xeu
vm=suse-glab
disk=/opt/images/$vm/disk1.img
iso=/opt/iso/openSUSE-Leap-15.6-NET-x86_64-Current.iso
tap=tap1

bhyve -AHP -s 0:0,hostbridge -s 1:0,lpc \
        -s 2:0,virtio-net,$tap -s 3:0,virtio-blk,$disk \
        -s 4:0,ahci-cd,$iso -c 1 -m 2048M \
	-l com1,stdio \
        -l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd,/opt/images/$vm/BHYVE_UEFI_VARS.fd \
        $vm
bhyvectl --destroy --vm=$vm
exit 0

