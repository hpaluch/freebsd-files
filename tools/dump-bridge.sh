#!/bin/sh
set -xeuo pipefail

d0=/mnt/nfs/fbsd-bridge-issue

[ -d "$d0" ] || {
	echo "ERROR: dir '$d0' does not exit is /mnt/nfs mounted?" >&2
	exit 1
}
d="$d0/`hostname`"
mkdir -pv "$d"
# copy files of interest
cp -v /etc/hostid /etc/rc.conf /etc/rc.firewall /etc/sysctl.conf "$d"

dmesg | fgrep 'Ethernet address' | tee "$d/dmesg-eth-addresses.txt"
sysctl -a | tee "$d/sysctl-a.txt"
arp -a    | tee "$d/arp-a.txt"
ifconfig  | tee "$d/ifconfig.txt"
ifconfig -u  | tee "$d/ifconfig-u.txt"
( netstat -in && netstat -rn ) | tee "$d/netstat.txt"
exit 0


