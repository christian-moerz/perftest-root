#!/bin/sh

#set -x
#set -e
. ./settings.sh
. ./setup.sh

: ${DISKTYPE:=virtio-blk}
: ${MEMDISK_SIZE:=12G}
: ${SECTORSIZE:=4096}
: ${DISKPARM:=",sectorsize=${SECTORSIZE},nocache"}
: ${YIELD:=-H}
: ${WIRED:=""}

# sysctl net.inet.ip.forwarding=1
setup_cpu

setup_memdisk ${MEMDISK_SIZE}

TAPDEV=$(ifconfig tap create)
ifconfig ${TAPDEV} name ${IFNAME}
ifconfig ${IFNAME} inet ${HOST_IP}/${HOST_NET}
ifconfig ${IFNAME} up

pfctl -t jailaddrs -Ta ${GUEST_IP}

bhyvectl --destroy --vm=${VMNAME} > /dev/null 2>&1

PINPARAMS=

if [ "$1" == "pin" ]; then
    PINPARAMS=${BHYVEPIN}
fi
if [ "wired" == "${WIRED}" ]; then
    WIRED=-S
else
    WIRED=
fi

#	-s 4,ahci-cd,${CDROM} \
# Then start a bhyve session
echo Starting bhyve...
/usr/bin/cpuset -c -l ${CPUPIN} \
/usr/sbin/bhyve -A -c ${CPUS} -D ${YIELD} -m ${MEMORY} \
		${PINPARAMS} ${WIRED} \
		-s 0,hostbridge \
		-s 1,lpc \
		-s 2,virtio-net,${TAPDEV} \
		-s 3,virtio-blk,/dev/zvol/${ZVOL},direct   \
		-s 4,${DISKTYPE},/dev/${MEMDISK_PATH} \
		-s 31,fbuf,tcp=127.0.0.1:5900,w=1024,h=800,tablet \
		-l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd \
		-l com1,/dev/nmdm${VMNAME}0A \
		${VMNAME} &
BHYVEPID=$!
echo ${BHYVEPID} > .bhyvepid

wait ${BHYVEPID}

echo bhyve terminated.
bhyvectl --destroy --vm=${VMNAME} > /dev/null 2>&1

pfctl -t jailaddrs -Td ${GUEST_IP}

ifconfig ${IFNAME} destroy
destroy_memdisk
