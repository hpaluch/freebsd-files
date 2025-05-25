#!/bin/sh
set -xeu
camcontrol devlist
gpart list da1
gpart show da1
cat /etc/fstab
exit 0

