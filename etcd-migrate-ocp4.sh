#!/bin/bash

# Define kubeconfig
kubeconfig="--kubeconfig=/home/lab/ocp4/auth/kubeconfig"

# Define lock file
LOCK_FILE=/.etcd-migration-ocp4 

# Define etcd_disk
ETCD_DISK=vdb

# Exit if the $LOCK_FILE exists, etcd-migration already done
if [ -f ${LOCK_FILE} ]
then
    echo "Lock file detected: ${LOCK_FILE}. Etcd migration already completed, exit 0"
    exit 0  
fi

# Abort if etcd_disk is not defined
if [ -z "${ETCD_DISK}" ]
then
  echo "ERROR ETCD_DISK variable not defined, aborting"
  exit 1
fi

# Exit if etcd_disk does not exists on master
sleep 90
MASTER_ETCD_DISK=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/lab_rsa core@master01 'sudo fdisk -l' | grep /dev/${ETCD_DISK} | wc -l)
if [ ${MASTER_ETCD_DISK} -eq  0 ]
then
  echo "ETCD_DISK='${ETCD_DISK}' does NOT exist on master01, MASTER_ETCD_DISK='${MASTER_ETCD_DISK0}', exit 0"
  exit 0
fi

# Wait to OCP startup
echo "Waiting for OCP cluster startup ..."
/home/lab/wait.sh 2

# Create the etcd-migration MCP, partition etcd_disk and create FS
echo "Running the etcd-migration MCP /home/lab/ocp4/etcd-mc-0.yml, partition disk and create FS ..."
oc create -f /home/lab/ocp4/etcd-mc-0.yml $kubeconfig
if [ $? -ne 0 ]
then
  echo "ERROR Could not create etcd-mc-0.yml, aborting"
  exit 1
fi
sleep 30

# Wait to MCP to finish
echo "Waiting to etcd-mc-0.yml to finish ..."
/home/lab/wait.sh 1

# Create the etcd-migration MCP, mount /var/lib/etcd on new partition
echo "Running the etcd-migration MCP /home/lab/ocp4/etcd-mc-1.yml, mount /var/lib/etcd on new partition ..."
oc create -f /home/lab/ocp4/etcd-mc-1.yml $kubeconfig
if [ $? -ne 0 ]
then
  echo "ERROR Could not create etcd-mc-1.yml, aborting"
  exit 1
fi
sleep 30

# Wait to MCP to finish
echo "Waiting to etcd-mc-1.yml to finish ..."
/home/lab/wait.sh 1

# Verify that etcd-migration has performed, /var/lib/etcd mounted on etcd_disk partition
echo "Verify that etcd-migration has performed, /var/lib/etcd mounted on etcd_disk partition"
MOUNT_ETCD_DISK=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/lab_rsa core@master01 'sudo df -h' | grep /dev/${ETCD_DISK} | grep /var/lib/etcd | wc -l)
if [ ${MOUNT_ETCD_DISK} -eq  0 ]
then
  echo "ERROR ETCD_DISK='${ETCD_DISK}' partition NOT mounted on /var/lib/etcd in master01, MOUNT_ETCD_DISK='${MOUNT_ETCD_DISK0}', aborting"
  exit 1
fi

# Verify that etcd-migration has performed, /var/lib/etcd/member directory exists
echo "Verify that etcd-migration has performed, /var/lib/etcd/member directory exists"
MEMBER_ETCD_DISK=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/lab_rsa core@master01 'sudo ls -lrt /var/lib/etcd/member' | wc -l)
if [ ${MEMBER_ETCD_DISK} -eq  0 ]
then
  echo "ERROR Directory /var/lib/etcd/member doe NOT exists in master01, MEMBER_ETCD_DISK='${MEMBER_ETCD_DISK0}', aborting"
  exit 1
fi

# If migration done, create lock and exit
echo "Etcd migration completed successfully, exit 0"
touch ${LOCK_FILE}
exit 0
