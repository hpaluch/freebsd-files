#!/bin/sh
set -xeu
camcontrol devlist
gpart list nda0
gpart show nda0
cat /etc/fstab
exit 0

