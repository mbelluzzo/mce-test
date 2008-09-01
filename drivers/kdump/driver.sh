#!/bin/sh -xe
#
# Kdump test driver: test case will trigger panic, and then crash
# dump. The test result is collected via dumped vmcore. For more
# information about kdump dirver please refer to doc/README.kdump.
#
# Copyright (C) 2008-2009, Intel Corp.
#   Author: Huang Ying <ying.huang@intel.com>
#
# This file is based on kdump test case in LTP.
#
# This file is released under the GPLv2.
#

sd=$(dirname "$0")
export ROOT=`(cd $sd/../..; pwd)`

. $ROOT/lib/functions.sh
setup_path
. $ROOT/lib/dirs.sh

setup_crontab ()
{
    echo "Setup crontab."

    set +e
    crontab -r
    set -e
   
    # crontab in some distros will not read from STDIN.

    cat <<EOF > $WDIR/kdump.cron
SHELL=/bin/sh
PATH=/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin
MAILTO=root
@reboot cd "$(pwd)"; ${0} $conf >> $WDIR/log 2>&1; cat $WDIR/log > /dev/console
EOF

    crontab $WDIR/kdump.cron

    echo "Enable cron daemon by default."
    
    if [ -f /etc/init.d/crond ]; then
        cron=crond
    else
        # SUSE
        cron=cron
    fi

    # Red Hat and SUSE.
    if [ -x "/sbin/chkconfig" ]; then
        /sbin/chkconfig "${cron}" on
 
    # Debian and Ubuntu.
    elif [ -x "/sbin/update-rc.d" ]; then
        /sbin/update-rc.d "${cron}" defaults
    fi
}

setup_kdump ()
{
    echo "Start kdump daemon."
    /etc/init.d/kdump restart
    
    echo "Enable kdump daemon by default."
    # Red Hat and SUSE.
    if [ -x "/sbin/chkconfig" ]; then
        /sbin/chkconfig kdump on
        
    # Debian and Ubuntu.
    elif [ -x "/sbin/update-rc.d" ]; then
        /sbin/update-rc.d kdump defaults
    fi    
}

get_result ()
{
    vmcore=$(ls -t "${COREDIR}"/*/vmcore* 2>/dev/null | head -1)

    if [ -n "$vmcore" -a -f $vmcore ]; then
	export vmcore
	klog=$RDIR/$this_case/klog
	cat <<EOF > $WDIR/gdb.cmd
dump memory $klog log_buf log_buf+log_end
EOF
	set +e
	gdb -batch -batch-silent -x $WDIR/gdb.cmd $VMLINUX $vmcore \
	    > /dev/null 2>&1
	ret=$?
	set -e
	if [ $ret -eq 0 -a -s $klog ]; then
	    export klog
	else
	    echo "  Failed: can not get kernel log"
	    rm -rf $klog
	fi
    else
	echo "  Failed: can not get vmcore"
    fi

    export reboot=1

    $CDIR/$case_sh get_result
}

verify_case ()
{
    if [ -z "$vmcore" ]; then
	echo "  Failed: can not got vmcore"
    fi
    $CDIR/$case_sh verify
}

trigger_case ()
{
    # Be careful to define COREDIR.
    rm -rf "${COREDIR}"/*

    # Save STDIO buffers.
    sync
    $CDIR/$case_sh trigger
}

# Start test.
if [ $# -lt 1 ]; then
    die "Usage: $0 <config>"
fi

conf=$(basename "$1")

. $CONF_DIR/$conf

driver_prepare

# Check mandatory variables.
if [ -z "${COREDIR}" ]; then
    die "Fail: some mandatory variables are missing from configuration file."
fi

# Reboot the machine first to take advantage of boot parameter 
# changes.
if [ ! -f $WDIR/stamps/setupped ]; then
    echo "Setup test environment."

    setup_crontab

    $SDIR/setup.sh $CONF_DIR/$conf

    echo > $WDIR/stamps/setupped

    echo "System is going to reboot."
    /sbin/shutdown -r now
    sleep 60
    exit -1
fi

for case_sh in ${CASES}; do
    for this_case in $($CDIR/$case_sh enumerate); do
	export this_case
	_this_case=$(echo $this_case | tr '/' '_')

	if [ -f $WDIR/stamps/${_this_case}_done ]; then
	    continue
	fi

        # First Test.
	if [ ! -f $WDIR/stamps/first_test_checked ]; then
            echo "First test..."
            echo "Verify Boot Loader."
            if ! grep 'crashkernel=' /proc/cmdline; then
		die "Fail: error changing Boot Loader, no crashkernel=."
            fi
            setup_kdump
	    echo > $WDIR/stamps/first_test_checked
	fi

	if [ ! -f $WDIR/stamps/${_this_case}_triggered ]; then
	    echo > $WDIR/stamps/${_this_case}_triggered

	    echo "$this_case:" | tee -a $RDIR/result
	    mkdir -p $RDIR/$this_case
	    rm -rf $RDIR/$this_case/*

	    echo "Running current test $this_case."

	    trigger_case | tee -a $RDIR/result

	    triggering=1
	fi

        # Wait for machine fully booted.
	sleep 60

	if [ -z "$triggering" ]; then
            (get_result; verify_case) | tee -a $RDIR/result
	else
	    echo "  Failed: Failed to trigger kdump" | tee -a $RDIR/result
	fi
	echo > $WDIR/stamps/${_this_case}_done
    done
done

echo "Test run complete" | tee -a $RDIR/result

# We are done.
# Reset.
crontab -r

exit 0