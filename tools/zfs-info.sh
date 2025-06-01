#!/bin/sh
set -xeu
zpool list
zpool status
zpool history
zfs list
zfs list -t snap
exit 0
