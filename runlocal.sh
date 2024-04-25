#!/bin/sh

SECTORSIZE=$1
PAR=$2
DISK=$3
MIXED=$4
HOST=$(hostname)                                                  
IODEPTH=32

echo LOCAL RUN:::
echo Sectorsize: ${SECTORSIZE}
echo Disk:       ${DISK}
echo Parallel:   ${PAR}

TESTRUNS="randwrite randread write read randrw readwrite"

if [ "${MIXED}" == "mixed" ]; then
    BSMODE=--bsrange=${SECTORDEFAULT}-${SECTORRANGE_MAX}
    NAMETAG=mixed-${SECTORDEFAULT}-${SECTORRANGE_MAX}
    echo Running locally in mixed mode.
else
    BSMODE=--bs=${SECTORSIZE}
    NAMETAG=${SECTORSIZE}
fi

mkdir -p ${BASEDIR}/output

for TRUN in $TESTRUNS; do
echo Running ${TRUN}...
cpuset -c -l ${CPUPIN} \
       fio --rw=${TRUN} --name=IOPS-${TRUN}-${PAR} ${BSMODE} --direct=1 \
       --filename=/dev/${DISK}  --numjobs=${PAR} \
       --ioengine=${ENGINE} --iodepth=${IODEPTH} --refill_buffers --group_reporting \
       --runtime=${RUNTIME} --time_based \
       --output=${BASEDIR}/output/${HOST}-${TRUN}-${PAR}-${NAMETAG}.json \
       --output-format=json+
done
