#!/bin/sh
# create snapshot of this dataset
set -xeuo pipefail
sd=''
[ `id -u` -eq 0 ] || sd='doas'
ts=$(date '+%Y%m%d-%H%M')
snap=cbsd/bhyve/images/trac-dr@snap-$ts
$sd zfs snapshot "$snap"
exit 0

