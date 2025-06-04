#!/bin/sh
set -xeuo pipefail
# mount file on loopback device
# See: mdconfig(8)
mdconfig /zroot/bhyve/images/t2-may2025/t2-may2025.raw
exit 0
