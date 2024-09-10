#!/bin/bash

# Define kubeconfig
kubeconfig="--kubeconfig=/home/lab/ocp4/auth/kubeconfig"

# Define lock files
LOCK_MIGRATION=/.etcd-migration-ocp4 
LOCK_WIPE=/.etcd-wipe-ocp4

# Define ssh_args
SSH_ARGS="-o StrictHostKeyChecking=no -i ~/.ssh/lab_rsa"

# Define etcd_disk
ETCD_DISK=vdb
ETCD_DISK_SIZE=10GiB
ETCD_DISK_LABEL=ephemeral0
ETCD_DISK_FS=vfat

# Define master list
MASTER_LIST="master01 master02 master03"

# Exit if the $LOCK_MIGRATION exists, etcd-migration already done
if [ -f ${LOCK_MIGRATION} ]
then
    echo "[INFO] Lock file detected: ${LOCK_MIGRATION}. Etcd migration already completed, exit 0"
    exit 0  
fi

# Abort if etcd_disk is not defined
if [ -z "${ETCD_DISK}" ]
then
  echo "[ERROR] ETCD_DISK variable not defined, aborting"
  exit 1
fi

# Wait to OCP startup
echo "[INFO] Waiting for OCP cluster startup ..."
/home/lab/wait.sh 1

# Exit if etcd_disk does not exist on masters
echo "[INFO] Checking if etcd_disk exist on masters ..."
for master in ${MASTER_LIST}
do
  MASTER_ETCD_DISK=$(ssh ${SSH_ARGS} core@${master} 'sudo fdisk -l' | grep /dev/${ETCD_DISK} | wc -l)
  if [ ${MASTER_ETCD_DISK} -eq  0 ]
  then
    echo "[WARN] ETCD_DISK='${ETCD_DISK}' does NOT exist in ${master}, MASTER_ETCD_DISK='${MASTER_ETCD_DISK}'. Not executing etcd migration, exit 0"
    exit 0
  fi
done

# Exit if etcd_disk size is not the expected
echo "[INFO] Checking if etcd_disk_size is the expected ..."
for master in ${MASTER_LIST}
do
  MASTER_ETCD_DISK_SIZE=$(ssh ${SSH_ARGS} core@${master} 'sudo fdisk -l' | grep /dev/${ETCD_DISK} | cut -d: -f2 | cut -d, -f1 | sed 's/ //mg')
  if [ ! "${MASTER_ETCD_DISK_SIZE}" == "${ETCD_DISK_SIZE}" ]
  then
    echo "[WARN] MASTER_ETCD_DISK_SIZE='${MASTER_ETCD_DISK_SIZE}' NOT equal to expected ETCD_DISK_SIZE='${ETCD_DISK_SIZE}' in ${master} for ETCD_DISK='${ETCD_DISK}'. Not executing etcd migration, exit 0"
    exit 0
  fi
done

# Exit if etcd_disk_fs is not the expected
echo "[INFO] Checking if etcd_disk_fs is the expected ..."
for master in ${MASTER_LIST}
do
  MASTER_ETCD_DISK_FS=$(ssh ${SSH_ARGS} core@${master} "sudo blkid /dev/${ETCD_DISK}" | awk -F"TYPE=" '{print $2}' | sed 's/"//mg')
  if [ ! "${MASTER_ETCD_DISK_FS}" == "${ETCD_DISK_FS}" ]
  then
    echo "[WARN] MASTER_ETCD_DISK_FS='${MASTER_ETCD_DISK_FS}' NOT equal to expected ETCD_DISK_FS='${ETCD_DISK_FS}' in ${master} for ETCD_DISK='${ETCD_DISK}'. Not executing etcd migration, exit 0"
    exit 0
  fi
done

# Exit if etcd_disk_label is not the expected
echo "[INFO] Checking if etcd_disk_label is the expected ..."
for master in ${MASTER_LIST}
do
  MASTER_ETCD_DISK_LABEL=$(ssh ${SSH_ARGS} core@${master} "sudo blkid /dev/${ETCD_DISK}" | awk -F"LABEL=" '{print $2}' | awk -F" " '{print $1}' | sed 's/"//mg')
  if [ ! "${MASTER_ETCD_DISK_LABEL}" == "${ETCD_DISK_LABEL}" ]
  then
    echo "[WARN] MASTER_ETCD_DISK_LABEL='${MASTER_ETCD_DISK_LABEL}' NOT equal to expected ETCD_DISK_LABEL='${ETCD_DISK_LABEL}' in ${master} for ETCD_DISK='${ETCD_DISK}'. Not executing etcd migration, exit 0"
    exit 0
  fi
done

# Wipe master etcd disks
echo "[INFO] Wiping etcd_disk keeping the original disk label, if required ..."
if [ -f ${LOCK_WIPE} ]
then
  echo "[INFO] Detected LOCK_WIPE=${LOCK_WIPE}, etcd disks already wiped"
else
  for master in ${MASTER_LIST}
  do
    ssh ${SSH_ARGS} core@${master} sudo wipefs -a /dev/${ETCD_DISK}
    if [ $? -ne 0 ]
    then
      echo "[ERROR] Could NOT wipe disk /dev/${ETCD_DISK} in ${master} , aborting"
      exit 1
    fi
    ssh ${SSH_ARGS} core@${master} sudo e2label /dev/${ETCD_DISK} ${ETCD_DISK_LABEL}
    if [ $? -ne 0 ]
    then
      echo "[ERROR] Could NOT keep LABEL '${ETCD_DISK_LABEL}' for disk /dev/${ETCD_DISK} in ${master} , aborting"
      exit 1
    fi
  done
  sudo touch ${LOCK_WIPE}
fi

# Create the etcd-migration MCP, partition etcd_disk and create FS
echo "[INFO] Running the etcd-migration MCP /home/lab/ocp4/etcd-mc-0.yml, partition disk and create FS ..."
oc apply -f /home/lab/ocp4/etcd-mc-0.yml $kubeconfig
if [ $? -ne 0 ]
then
  echo "[ERROR] Could not create etcd-mc-0.yml, aborting"
  exit 1
fi
sleep 60

# Create the etcd-migration MCP, mount /var/lib/etcd on new partition
echo "[INFO] Running the etcd-migration MCP /home/lab/ocp4/etcd-mc-1.yml, mount /var/lib/etcd on new partition ..."
oc apply -f /home/lab/ocp4/etcd-mc-1.yml $kubeconfig
if [ $? -ne 0 ]
then
  echo "[ERROR] Could not create etcd-mc-1.yml, aborting"
  exit 1
fi
sleep 60

# Wait to MCP to finish
echo "[INFO] Waiting to etcd-mc-1.yml to finish ..."
/home/lab/wait.sh 1

# Verify that etcd-migration has performed successfully, /var/lib/etcd mounted on etcd_disk partition
echo "[INFO] Verify that etcd-migration has performed successfully, /var/lib/etcd mounted on etcd_disk partition"
for master in ${MASTER_LIST}
do
  MOUNT_ETCD_DISK=$(ssh ${SSH_ARGS} core@${master} 'sudo df -h' | grep /dev/${ETCD_DISK} | grep /var/lib/etcd | wc -l)
  if [ ${MOUNT_ETCD_DISK} -eq  0 ]
  then
    echo "[ERROR] ETCD_DISK='${ETCD_DISK}' partition NOT mounted on /var/lib/etcd in ${master}, MOUNT_ETCD_DISK='${MOUNT_ETCD_DISK}', aborting"
    exit 1
  fi
done

# Verify that etcd-migration has performed, /var/lib/etcd/member directory exists
echo "[INFO] Verify that etcd-migration has performed, /var/lib/etcd/member directory exists"
for master in ${MASTER_LIST}
do
  MEMBER_ETCD_DISK=$(ssh ${SSH_ARGS} core@${master} 'sudo ls -lrt /var/lib/etcd/member' | wc -l)
  if [ ${MEMBER_ETCD_DISK} -eq  0 ]
  then
    echo "[ERROR] Directory /var/lib/etcd/member does NOT exists in ${master}, MEMBER_ETCD_DISK='${MEMBER_ETCD_DISK}', aborting"
    exit 1
  fi
done

# If migration done, create lock and exit
echo "[INFO] Etcd migration completed successfully, exit 0"
sudo touch ${LOCK_MIGRATION}
exit 0
