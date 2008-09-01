#!/bin/sh
#
# Simple test driver: run test cases one by one, assuming test case
# will not trigger panic or reboot.
#
# Copyright (C) 2008-2009, Intel Corp.
#   Author: Huang Ying <ying.huang@intel.com>
#
# This file is released under the GPLv2.
#

sd=$(dirname "$0")
export ROOT=`(cd $sd/../..; pwd)`

. $ROOT/lib/functions.sh
setup_path
. $ROOT/lib/dirs.sh

tmp_klog=$WDIR/simple_klog_tmp

klog_begin()
{
    dmesg > $tmp_klog
    stat -c '%s' $tmp_klog
}

klog_end()
{
    local sz_before=$1
    local sz_after sz_result
    dmesg > $tmp_klog
    sz_after=$(stat -c '%s' $tmp_klog)
    sz_result=$(expr $sz_after - $sz_before)
    dd if=$tmp_klog of=$klog bs=1 count=$sz_result \
	skip=$sz_before > /dev/null 2>&1
    local ret=$?
    if [ $ret -ne 0 ]; then
	echo $sz_before $sz_after $sz_result
	echo "  Failed: Can not get klog" | tee -a $RDIR/result
	#rm -f $klog
    fi
    return $ret
}

test_all()
{
    for case_sh in $CASES; do
	for this_case in $($CDIR/$case_sh enumerate); do
	    export this_case
	    mkdir -p $RDIR/$this_case
	    rm -rf $RDIR/$this_case/*
	    echo "$this_case:" | tee -a $RDIR/result
	    klog=$RDIR/$this_case/klog

	    mkdir -p $WDIR/$this_case
	    rm -rf $WDIR/$this_case/*
	    err_log=$WDIR/$this_case/err_log

	    random_sleep
	    local before=$(klog_begin)
	    $CDIR/$case_sh trigger 2>$err_log | tee -a $RDIR/result
	    klog_end $before
	    $CDIR/$case_sh get_result 2>$err_log | tee -a $RDIR/result
	    $CDIR/$case_sh verify 2>$err_log | tee -a $RDIR/result
	done
    done
}

if [ $# -lt 1 ]; then
    die "Usage: $0 <config>"
fi

conf=$(basename "$1")

. $CONF_DIR/$conf

driver_prepare

start_background
test_all
stop_background