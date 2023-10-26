#!/bin/bash

# Configuration
RETRY=2
WAITSEC=600
NS=openshift-kube-apiserver
CRITICAL_LOG="x509: certificate signed by unknown authority"
EXPIRED_CERTS=0

# Set KUBECONFIG
export KUBECONFIG=/home/lab/ocp4/auth/kubeconfig

# Wait for Openshift to auto-renew certs
echo "Start ${0} process."

# Check if Openshift has auto-renewed certs and trigger the auto-renew process if needed
echo "Checking if Openshift has auto-renewed the internal certificates successfully."
for i in $(seq 1 ${RETRY})
do

  # Wait between retries
  echo "Waiting for OpenShift to auto-renew the internal certificates..."
  sleep ${WAITSEC}

  # Searching the CRITICAL_LOG on failed pod
  for pod in $(oc get pods -n ${NS} --no-headers | grep -vE "Running|Completed" | awk '{print $1}')
  do
  
    # Search critical logs
    echo "Searching critical logs on failed ${pod} pod."
    COUNT=0

    while true
    do
      # Loop for searching critical logs  
      ((COUNT=COUNT+1))
      RETURN=0
      LOGS=$(oc logs ${pod} -n ${NS}) || RETURN=1 
      if [ ${RETURN} -eq 1 ]
      then
        echo "[$COUNT] Could not read logs from failed ${pod} pod, trying again..."
      else
        FILTER=$(echo ${LOGS} | grep "${CRITICAL_LOG}" | wc -l) || RETURN=1
        if [ ${RETURN} -eq 0 ] && [ $FILTER -ne 0 ]
        then
          echo "[$COUNT] Found the critcal log '${CRITICAL_LOG}' in failed ${pod} pod."
          EXPIRED_CERTS=1 
          break
        fi
        if [ ${COUNT} -gt 10 ]
        then
          echo "[$COUNT] Reached the maximum tries for searching critical logs in faled pods."
          break
        fi
      fi
      sleep 30
    done

  done

  # Trigger the internal certificates auto-renew process, if required
  if [ ${EXPIRED_CERTS} -eq 1 ]
  then

    # Run the trigger
    RETURN=0
    echo "Critical logs found. Openshift has NOT auto-renewed the internal certificates successfully."
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
    echo "No critical logs found. Openshift has auto-renewed the internal certificates successfully."
  fi

done

echo "Finish ${0} process."
exit 0
