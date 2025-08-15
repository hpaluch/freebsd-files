#!/bin/sh
# prints kernel like git revision, for example: "main-n279627-08f5e06c5e33"
# ripped from /usr/src/sys/conf/newvers.sh
set -euo pipefail

git_cmd=git
VCSTOP=`pwd`

[ -d .git ] || {
	echo "ERROR: No .git/ in current directory" 2>&1
	exit 1
}


git_tree_modified()
{
        ! $git_cmd "--work-tree=${VCSTOP}" -c core.checkStat=minimal -c core.fileMode=off diff --quiet
}


if [ -n "$git_cmd" ] ; then
        git=$($git_cmd rev-parse --verify --short=12 HEAD 2>/dev/null)
        if [ "$($git_cmd rev-parse --is-shallow-repository)" = false ] ; then
                git_cnt=$($git_cmd rev-list --first-parent --count HEAD 2>/dev/null)
                if [ -n "$git_cnt" ] ; then
                        git="n${git_cnt}-${git}"
                fi
        fi
        git_b=$($git_cmd rev-parse --abbrev-ref HEAD)
        if [ -n "$git_b" -a "$git_b" != "HEAD" ] ; then
                git="${git_b}-${git}"
        fi
        if git_tree_modified; then
                git="${git}-dirty"
                modified=yes
        fi
        #git=" ${git}"
fi
echo "$git"
exit 0
