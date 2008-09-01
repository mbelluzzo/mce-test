#
# Function library: provide common functions
#
# Copyright (C) 2008-2009, Intel Corp.
#   Author: Huang Ying <ying.huang@intel.com>
#
# This file is released under the GPLv2.
#

setup_path()
{
    export PATH=$ROOT/bin:$PATH
}

script_dir()
{
    rd=$(dirname "$0")
    (cd $rd; pwd)
}

relative_path()
{
    len1=${#1}
    len2=${#2}
    if [ $len1 -eq 0 -o $len1 -ge $len2 -o "${2:0:$len1}" != "$1" ]; then
	die "$2 is not the sub-path of $1!"
    fi
    len1=$((len1 + 1))
    echo "${2:$len1}"
}

die()
{
    echo "$@" 1>&2
    exit -1
}

driver_prepare()
{
    mkdir -p $WDIR/stamps
}

check_kern_warning_bug()
{
    f="$1"
    [ -n "$f" ] || die "missing parameter for check_kern_warning"
    grep -e '----\[ cut here \]---' $f > /dev/null || \
	grep -e 'BUG:' $f > /dev/null
}

random_sleep()
{
    s=$((RANDOM / 6553))
    sleep $s
}

start_background()
{
    if [ -n "$BACKGROUND" ]; then
	eval "$BACKGROUND" "&>$WDIR/background_log &" || \
	    die "Failed to start background testing: $BACKGROUND"
	pid_background=$!
    fi
}

stop_background()
{
    if [ -n "$pid_background" ]; then
	kill -TERM -$pid_background || true
	kill $pid_background || true
    fi
}

filter_fake_panic()
{
    orig_klog=$1
    new_klog=$2
    [ $# -eq 2 ] || die "missing parameter for filter_fake_panic"

    pn=$(grep -n "Fake kernel panic" $orig_klog | cut -d ':' -f 1 | head -1)
    if [ -z "$pn" ]; then
	cp $orig_klog $new_klog
    else
	sed -n "1,${pn}p" < $orig_klog > $new_klog
    fi
}