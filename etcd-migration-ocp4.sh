#!/bin/bash

# Define kubeconfig
kubeconfig="--kubeconfig=/home/lab/ocp4/auth/kubeconfig"

# Define lock files
LOCK_MIGRATION=/.etcd-migration-ocp4 
LOCK_WIPE=/.etcd-wipe-ocp4

# Define etcd_disk
ETCD_DISK=vdb

# Define master list
MASTER_LIST="master01 master02 master03"

# Exit if the $LOCK_MIGRATION exists, etcd-migration already done
if [ -f ${LOCK_MIGRATION} ]
then
    echo "Lock file detected: ${LOCK_MIGRATION}. Etcd migration already completed, exit 0"
    exit 0  
fi

# Abort if etcd_disk is not defined
if [ -z "${ETCD_DISK}" ]
then
  echo "ERROR ETCD_DISK variable not defined, aborting"
  exit 1
fi

# Wait to OCP startup
echo "Waiting for OCP cluster startup ..."
/home/lab/wait.sh 1

# Wipe master etcd disks
if [ -f ${LOCK_WIPE} ]
then
  echo "Detected LOCK_WIPE=${LOCK_WIPE}, etcd disks already wiped"
else
  for master in ${MASTER_LIST}
  do
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/lab_rsa core@${master} sudo wipefs -a /dev/${ETCD_DISK}
    if [ $? -ne 0 ]
    then
      echo "ERROR coul not wipe disk /dev/${ETCD_DISK} in ${master} , aborting"
      exit 1
    fi
  done
  sudo touch ${LOCK_WIPE}
fi

# Exit if etcd_disk does not exists on masters
for master in ${MASTER_LIST}
do
  MASTER_ETCD_DISK=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/lab_rsa core@${master} 'sudo fdisk -l' | grep /dev/${ETCD_DISK} | wc -l)
  if [ ${MASTER_ETCD_DISK} -eq  0 ]
  then
    echo "ETCD_DISK='${ETCD_DISK}' does NOT exist on ${master}, MASTER_ETCD_DISK='${MASTER_ETCD_DISK0}'. Not executing etcd migration, exit 0"
    exit 0
  fi
done

# Create the etcd-migration MCP, partition etcd_disk and create FS
echo "Running the etcd-migration MCP /home/lab/ocp4/etcd-mc-0.yml, partition disk and create FS ..."
oc apply -f /home/lab/ocp4/etcd-mc-0.yml $kubeconfig
if [ $? -ne 0 ]
then
  echo "ERROR Could not create etcd-mc-0.yml, aborting"
  exit 1
fi
sleep 60

# Create the etcd-migration MCP, mount /var/lib/etcd on new partition
echo "Running the etcd-migration MCP /home/lab/ocp4/etcd-mc-1.yml, mount /var/lib/etcd on new partition ..."
oc apply -f /home/lab/ocp4/etcd-mc-1.yml $kubeconfig
if [ $? -ne 0 ]
then
  echo "ERROR Could not create etcd-mc-1.yml, aborting"
  exit 1
fi
sleep 60

# Wait to MCP to finish
echo "Waiting to etcd-mc-1.yml to finish ..."
/home/lab/wait.sh 1

# Verify that etcd-migration has performed successfully, /var/lib/etcd mounted on etcd_disk partition
echo "Verify that etcd-migration has performed successfully, /var/lib/etcd mounted on etcd_disk partition"
for master in ${MASTER_LIST}
do
  MOUNT_ETCD_DISK=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/lab_rsa core@${master} 'sudo df -h' | grep /dev/${ETCD_DISK} | grep /var/lib/etcd | wc -l)
  if [ ${MOUNT_ETCD_DISK} -eq  0 ]
  then
    echo "ERROR ETCD_DISK='${ETCD_DISK}' partition NOT mounted on /var/lib/etcd in ${master}, MOUNT_ETCD_DISK='${MOUNT_ETCD_DISK0}', aborting"
    exit 1
  fi
done

# Verify that etcd-migration has performed, /var/lib/etcd/member directory exists
echo "Verify that etcd-migration has performed, /var/lib/etcd/member directory exists"
for master in ${MASTER_LIST}
do
  MEMBER_ETCD_DISK=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/lab_rsa core@${master} 'sudo ls -lrt /var/lib/etcd/member' | wc -l)
  if [ ${MEMBER_ETCD_DISK} -eq  0 ]
  then
    echo "ERROR Directory /var/lib/etcd/member does NOT exists in ${master}, MEMBER_ETCD_DISK='${MEMBER_ETCD_DISK0}', aborting"
    exit 1
  fi
done

# If migration done, create lock and exit
echo "Etcd migration completed successfully, exit 0"
sudo touch ${LOCK_MIGRATION}
exit 0
