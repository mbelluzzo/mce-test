#!/bin/sh
#
# Software injection based test cases - panic cases: test cases are
# triggered via bin/inject tool, and they will trigger kernel panic.
#
# Copyright (C) 2008-2009, Intel Corp.
#   Author: Huang Ying <ying.huang@intel.com>
#
# This file is released under the GPLv2.
#

. $ROOT/lib/functions.sh
. $ROOT/lib/dirs.sh
. $ROOT/lib/mce.sh
. $ROOT/lib/soft-inject.sh

enumerate()
{
    soft_inject_enumerate
}

trigger()
{
    soft_inject_trigger
}

get_result()
{
    soft_inject_get_klog

    case "$bcase" in
	fatal|fatal_irq|fatal_timeout)
	    get_mcelog_from_klog $klog $mcelog_result
	    ;;
	*)
	    echo '!!! Unknown case: $this_case !!!'
    esac
}

verify()
{
    removes="TSC"
    case "$bcase" in
	fatal|fatal_irq)
	    removes="TSC RIP"
	    mce_panic=": Fatal machine check"
	    soft_inject_verify_mcelog
	    verify_klog $klog
	    verify_panic $klog "$mce_panic"
	    ;;
	fatal_timeout)
	    removes="TSC RIP"
	    mce_panic=": Machine check"
	    soft_inject_verify_mcelog
	    verify_klog $klog
	    verify_panic $klog "$mce_panic"
	    verify_timeout $klog
	    ;;
	*)
	    echo "!!! Unknown case: $this_case !!!"
    esac
}

soft_inject_main "$@"