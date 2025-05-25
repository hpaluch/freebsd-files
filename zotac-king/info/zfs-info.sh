#!/bin/sh
set -xeu
zpool list
zpool status
zpool history
zfs list
exit 0
