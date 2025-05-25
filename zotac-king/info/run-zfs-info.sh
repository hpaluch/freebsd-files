#!/bin/sh
set -xeuo pipefail
doas ./zfs-info.sh 2>&1 | tee info-zfs.txt
exit 0
