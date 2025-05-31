#!/bin/sh
set -xeuo pipefail
# mount file on loopback device
# See: mdconfig(8)
mdconfig /zroot/bhyve/images/alpine1/alpine1.raw
exit 0
