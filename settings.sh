#
# Configuration settings
#

BASEDIR=/root/vms/disklab
VMNAME=perftest
ZVOL=zroot/vols/${VMNAME}

HOST_IP=192.168.168.1
HOST_NET=30
GUEST_IP=192.168.168.2
GUEST_NET=30
IFNAME=${VMNAME}0

ISO=/home/lclchristianm/Downloads/FreeBSD-13.2-RELEASE-amd64-disc1.iso
CONSOLE=2

MEMORY=2G
MEMDISK_SIZE=16G

RUNTIME=60

ENGINE="posixaio"
export ENGINE
DISKTYPES="virtio-blk nvme ahci-hd"
SECTORSIZES="512 4096 8192"
WIRETYPES="nowire wired"
SECTORRANGE_MAX=131072
SECTORDEFAULT=4096
CPUS=4
PINNINGS="pin nopin"
YIELD="-H"

HOSTNAME=$(hostname)
case $HOSTNAME in
    tenforward)
	CPUPIN=4-7
	SYSPIN=0-3
	WORKSPACE=/home/lclchristianm/workspace/perftest
	BHYVEPIN="-p 0:4 -p 1:5 -p 2:6 -p 3:7"
	;;
    frame14)
	CPUPIN=0-3
	SYSPIN=4-7
	WORKSPACE=/home/lclchristianm/Documents/workspace/perftest
	BHYVEPIN="-p 0:0 -p 1:1 -p 2:2 -p 3:3"
	;;
esac
