#!/bin/sh
#

. ./settings.sh
. ./setup.sh

sysctl net.inet.ip.forwarding=1
kldload nmdm
kldload vmm

# make sure packages are available
# setup_packages

DOUBLE=$((CPUS * 2))
PARALLELS="1 ${CPUS} ${DOUBLE}"
COUNTER=1
export CPUPIN
export SYSPIN
export RUNTIME

sysctl net.inet.ip.forwarding=1

if [ ! -e /dev/zvol/${ZVOL}p2 ]; then
    echo "Incorrectly configured - do not know /dev/zvol/${ZVOL}p2"
    exit 1
fi

fsck -y /dev/zvol/${ZVOL}p2
mount /dev/zvol/${ZVOL}p2 /mnt
sysrc -f /mnt/boot/loader.conf autoboot_delay=0
sysrc -R /mnt hostname="${VMNAME}"
sysrc -R /mnt ifconfig_vtnet0="${GUEST_IP}/${GUEST_NET}"
sysrc -R /mnt defaultrouter="${HOST_IP}"
rm -f /mnt/root/output/*.json
umount /mnt

rm ${BASEDIR}/output/*.json

#
# Finished init
#

export BASEDIR

# run through the various sector sizes and configurations
for PINNING in ${PINNINGS}; do
    for PARRUN in ${PARALLELS}; do
	if [ "pin" == "${PINNING}" ]; then
	    SECTORSIZE=${SECTORDEFAULT}
	    SECTORRANGE="${SECTORSIZE}-${SECTORRANGE_MAX}"
	    setup_memdisk ${MEMDISK_SIZE}
	    SECTORSIZE=${SECTORRANGE}
	    export SECTORDEFAULT
	    export SECTORRANGE_MAX
	    ${BASEDIR}/runlocal.sh ${SECTORSIZE} ${PARRUN} \
		      ${MEMDISK_PATH} mixed
	    destroy_memdisk
	fi
	
	for SECTORSIZE in ${SECTORSIZES}; do
	    if [ "pin" == "${PINNING}" ]; then
		# only run this once, during pin
		setup_memdisk ${MEMDISK_SIZE}
		export SECTORDEFAULT
		export SECTORRANGE_MAX
		${BASEDIR}/runlocal.sh ${SECTORSIZE} ${PARRUN} \
			  ${MEMDISK_PATH} nomix
		destroy_memdisk
	    fi
	    
	    for WIRED in ${WIRETYPES}; do
		export WIRED
		
		for DISKTYPE in ${DISKTYPES}; do
		    echo "=== New test run ${COUNTER} ==="
		    echo "Sectorsize ${SECTORSIZE}"
		    echo "Parallel procs ${PARRUN}"
		    echo "Disk type ${DISKTYPE}"
		    echo "Wired ${WIRED}"
		    
		    setup_runparams
		    
		    # Start bhyve guest
		    export SECTORSIZE
		    export DISKTYPE
		    export DISKPARMS
		    
		    echo Starting bhyve...
		    rm ${BASEDIR}/.bhyvepid
		    ${BASEDIR}/snapshot-vm.sh &
		    SCRIPTPID=$!
		    
		    # wait until we can ping the guest
		    waitforguest
		    
		    PROCID=$(cat ${BASEDIR}/.bhyvepid)
		    
		    # wait for ssh
		    sleep 5
		    
		    # run test suite
		    run_remote /root/run.sh
		    
		    # then kill the bhyve guest
		    await_bhyve_shutdown ${PROCID} ${SCRIPTPID}
		    
		    COUNTER=$((COUNTER+1))
		done
	    done
	done
    done
done

# Start one last time to transfer results
echo Starting bhyve...
rm ${BASEDIR}/.bhyvepid
${BASEDIR}/snapshot-vm.sh &
SCRIPTPID=$!

# wait until we can ping the guest
waitforguest

PROCID=$(cat ${BASEDIR}/.bhyvepid)

# wait for ssh
sleep 5
waitforguest_ssh

# transfer files
${BASEDIR}/transfer.sh

shutdown_guest
