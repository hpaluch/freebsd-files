#!/bin/sh
set -xeuo pipefail
sd=
[ `id -u` -eq 0 ] || sd=doas
d="$(dirname "$0")"
$sd $d/zfs-info.sh 2>&1 | tee info-zfs.txt
exit 0
