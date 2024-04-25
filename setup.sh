#
#
# Functions for setting up test disk and guest
#

setup_cpu() {
	# allow host to use cores 1-4
	cpuset -l ${SYSPIN} -s 1
	cpuset -c -l ${SYSPIN} -s 1

}

setup_memdisk() {
    DISKSIZE=$1
    
    if [ "" == "$1" ]; then
	echo Missing mem disk size parameter
	exit 1
    fi
    MEMDISK_PATH=$(mdconfig -a -t malloc -o reserve -s $1 -S ${SECTORSIZE})
    if [ "0" != "$?" ]; then
	exit $?
    fi
    export MEMDISK_PATH
}

destroy_memdisk() {
    mdconfig -d -u ${MEMDISK_PATH}
}

mountdisk() {
    RESULT=1
    while [ "0" != "${RESULT}" ]; do
	if [ -e /dev/zvol/${ZVOL}p2 ]; then
	    RESULT=0
	else
	    echo Awaiting disk volume...
	fi
	sleep 1
    done
	
    fsck -y /dev/zvol/${ZVOL}p2
    mount /dev/zvol/${ZVOL}p2 /mnt
}

setup_packages() {
    mountdisk
    pkg -c /mnt install fio
    umount /mnt
}

setup_runparams() {
    mountdisk

    # write $DISKTYPE
    echo $DISKTYPE > /mnt/root/disktype
    # write $SECTORSIZE
    echo $SECTORSIZE > /mnt/root/sectorsize
    # write PARRUN
    echo $PARRUN > /mnt/root/parallelrun
    # write PINNING
    echo $PINNING > /mnt/root/pinning
    # write RUNTIME
    echo $RUNTIME > /mnt/root/runtime
    # write WIRED
    echo $WIRED > /mnt/root/wired
    # write MIXED params
    echo "${SECTORDEFAULT}-${SECTORRANGE_MAX}" > /mnt/root/mixed
    
    case $DISKTYPE in
	virtio-blk)
	    echo vtbd1 > /mnt/root/mountpoint
	    DISKPARMS=",sectorsize=${SECTORSIZE},nocache"
	;;
	nvme)
	    echo nvd0 > /mnt/root/mountpoint
	    DISKPARMS=",sectsz=${SECTORSIZE}"
	;;
	ahci-hd)
	    echo ada0 > /mnt/root/mountpoint
	    DISKPARMS=""
	;;
    esac
    umount /mnt
}

waitforguest_ssh() {
    RESULT=1
    COUNTFAIL=0
    while [ "${RESULT}" != "0" ]; do
	ssh -i ${BASEDIR}/id_ecdsa lclchristianm@192.168.168.2 ls > /dev/null 2>&1
	RESULT=$?
	if [ "0" != "${RESULT}" ]; then
	    sleep 5
	fi
	COUNTFAIL=$((COUNTFAIL+1))
	if [ "$COUNTFAIL" == "10" ]; then
	    RESULT=0
	    echo Failed to connect to guest.
	fi
    done
}

shutdown_guest() {
    ssh -i ${BASEDIR}/id_ecdsa lclchristianm@192.168.168.2 doas poweroff
}

waitforguest() {
    RESULT=1

    echo -n "Awaiting guest on ${GUEST_IP}"

    while [ "$RESULT" != "0" ]; do
	echo -n "."
	ping -c 1 -t 1 -q ${GUEST_IP} > /dev/null 2>&1
	RESULT=$?
	if [ "0" == "${RESULT}" ]; then
	    RESULT=0
	fi
	sleep 1
    done
    echo "."
}

start_vm() {
    echo Starting bhyve...
    rm ${BASEDIR}/.bhyvepid
    ${BASEDIR}/snapshot-vm.sh &
    SCRIPTPID=$!
    export SCRIPTPID
}

run_remote() {
    RESULT=1
    COUNTFAIL=0
    while [ "${RESULT}" != "0" ]; do
	ssh -i ${BASEDIR}/id_ecdsa lclchristianm@192.168.168.2 doas $1
	RESULT=$?
	if [ "0" != "${RESULT}" ]; then
	    sleep 5
	fi
	COUNTFAIL=$((COUNTFAIL+1))
	if [ "$COUNTFAIL" == "10" ]; then
	    RESULT=0
	    echo Failed to connect to guest.
	fi
    done
}

await_bhyve_shutdown() {
    PROCID=$1
    SCRIPTPID=$2
    echo Terminating bhyve process ${PROCID}...
    kill -TERM ${PROCID}
    wait ${PROCID}
    wait ${SCRIPTPID}
    
    echo bhyve shut down.
    
    sleep 1
}
