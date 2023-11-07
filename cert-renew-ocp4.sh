#!/bin/bash

# Configuration
RETRY=3
MAXLOOP=60
NS=openshift-kube-apiserver
PODR=kube-apiserver-master
CRITICAL_LOG="x509: certificate signed by unknown authority"

# Set KUBECONFIG
export KUBECONFIG=/home/lab/ocp4/auth/kubeconfig

# Wait for Openshift to auto-renew certs
echo "Start ${0} process."

# Check if Openshift has auto-renewed certs and trigger the auto-renew process if needed
echo "Checking if Openshift has auto-renewed the internal certificates successfully."
for i in $(seq 1 ${RETRY})
do

  # Wait between retries
  EXPIRED_CERTS=0
  echo "Waiting for OpenShift to auto-renew the internal certificates..."
  sleep $(( 240*${i} ))

  # Approve CSRs
  echo "Approve pending/unissued certificate requests (CSR)."
  for csr in $(oc get csr -ojson | jq -r '.items[] | select(.status == {} ) | .metadata.name')
  do
    oc adm certificate approve ${csr}
  done
  sleep 30

  # Wait for API to come online
  COUNT=0
  until [ $(curl -k -s https://api.ocp4.example.com:6443/version?timeout=10s | jq -r '.major' | grep -v null | wc -l) -eq 1 ]
  do
    # Skip if needed
    [ ${EXPIRED_CERTS} -eq 1 ] && break

    # Loop
    ((COUNT=COUNT+1))
    echo "[$COUNT] Waiting for Openshift API to come online..."
    sleep 10

    # Timeout
    if [ ${COUNT} -gt ${MAXLOOP} ]
    then
      echo "[$COUNT] Reached the maximum tries for waiting for Openshift API."
      EXPIRED_CERTS=1
      break
    fi
  done
  echo "Openshift API is up."

  # Wait for authentication come online
  COUNT=0
  while true
  do
    # Skip if needed
    [ ${EXPIRED_CERTS} -eq 1 ] && break

    # Loop 
    ((COUNT=COUNT+1))
    code=$(curl -k -s https://oauth-openshift.apps.ocp4.example.com)
    if [[ ! -z ${code} ]] && [[ "${code:0:1}" == "{" ]] && [[ $(echo $code | jq -r '.code') -eq 403 ]]
    then
      break
    fi
    echo "[$COUNT] Waiting for authentication..."
    sleep 10

    # Timeout
    if [ ${COUNT} -gt ${MAXLOOP} ]
    then
      echo "[$COUNT] Reached the maximum tries for waiting for authentication."
      EXPIRED_CERTS=1
      break
    fi
  done
  echo "Authentication is ready."

  # Searching the CRITICAL_LOG on failed pod
  for pod in $(oc get pods -n ${NS} --no-headers | grep -vE "Running|Completed" | awk '{print $1}' | grep ${PODR})
  do

    # Skip if needed
    [ ${EXPIRED_CERTS} -eq 1 ] && break
  
    # Search critical logs
    echo "Searching critical logs on failed ${pod} pod."
    COUNT=0

    while true
    do

      # Loop for searching critical logs  
      ((COUNT=COUNT+1))
      RETURN=0

      # Check logs
      LOGS=$(oc logs ${pod} -n ${NS} 2>&1)
      FILTER=$(echo ${LOGS} | grep "${CRITICAL_LOG}" | wc -l) || RETURN=1
      if [ ${RETURN} -eq 0 ] && [ $FILTER -ne 0 ]
        then
          echo "[$COUNT] Found the critcal log '${CRITICAL_LOG}' in failed ${pod} pod."
          EXPIRED_CERTS=1 
          break
      else
        if [ ${RETURN} -eq 1 ]
        then
          echo "[$COUNT] Could not read logs from failed ${pod} pod, trying again..." 
        else
          echo "[$COUNT] NOT found critical log '${CRITICAL_LOG}' in failed ${pod} pod, trying again..."
        fi
      fi

      # Break the loop with timeout 
      if [ ${COUNT} -gt ${MAXLOOP} ]
      then
        echo "[$COUNT] Reached the maximum tries for searching critical logs in faled pods."
        break
      fi
      sleep 5

    done

  done

  # Trigger the internal certificates auto-renew process, if required
  if [ ${EXPIRED_CERTS} -eq 1 ]
  then

    # Run the trigger
    RETURN=0
    echo "Critical cluster status found. Openshift has NOT auto-renewed the internal certificates successfully."
    echo "Triggering Openshift internal certificates auto-renew process."
    oc get secret -A -o json | jq -r '.items[] | select(.metadata.annotations."auth.openshift.io/certificate-not-after" | 
    .!=null and fromdateiso8601<='$( date --date='+1year' +%s )') | "-n \(.metadata.namespace) \(.metadata.name)"' |
    xargs -n3 oc patch secret -p='{"metadata": {"annotations": {"auth.openshift.io/certificate-not-after": null}}}' || RETURN=1

    # Report trigger result
    if [ ${RETURN} -eq 1 ]
    then
      echo "Openshift internal certificates auto-renew process NOT triggered successfully."
    else
      echo "Openshift internal certificates auto-renew process triggered successfully." 
    fi
    
  else
    echo "No critical cluster status found. Openshift has auto-renewed the internal certificates successfully."
  fi

done

echo "Finish ${0} process."
exit 0
