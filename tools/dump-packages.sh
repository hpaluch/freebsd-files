#!/bin/sh
set -euo pipefail
d="$(dirname "$0")"
# manually installed packages:
pkg prime-list | tee $d/packages.lst
exit 0
