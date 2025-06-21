#!/bin/sh
set -xeu
camcontrol devlist
gpart list
gpart show
cat /etc/fstab
exit 0

