#!/bin/sh
. /root/vms/disklab/settings.sh
scp -i /root/vms/disklab/id_ecdsa lclchristianm@192.168.168.2:/root/output/\* ${WORKSPACE}/
chown lclchristianm ${WORKSPACE}/*.json

