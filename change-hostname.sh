#!/bin/sh

. ./settings.sh
. ./setup.sh

if [ "$1" == "" ]; then
    echo Missing hostname argument.
    exit 1
fi

echo Changing hostname to $1

rm /root/vms/disklab/.bhyvepid
start_vm
# sets SCRIPTPID

# wait until we can ping the guest
waitforguest

PROCID=$(cat ${BASEDIR}/.bhyvepid)

# wait for ssh
sleep 5

# run test suite
run_remote "sysrc hostname=$1"
shutdown_guest

# then kill the bhyve guest
await_bhyve_shutdown ${PROCID} ${SCRIPTPID}

