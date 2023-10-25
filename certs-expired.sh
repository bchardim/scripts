#!/bin/bash

format="%-8s%-8s%-60s%-26s%-60s\n"
printf "$format" STATE DAYS NAME EXPIRY NAMESPACE
printf "$format" ----- ---- ---- ------ ---------

oc get secrets -A -o go-template='{{range .items}}{{if eq .type "kubernetes.io/tls"}}{{.metadata.namespace}}{{" "}}{{.metadata.name}}{{" "}}{{index .data "tls.crt"}}{{"\n"}}{{end}}{{end}}' | while read namespace name cert
do
  certdate=`echo $cert | base64 -d | openssl x509 -noout -enddate|cut -d= -f2`
  epochcertdate=$(date -d "$certdate" +"%s")
  currentdate=$(date +%s)
  if ((epochcertdate > currentdate)); then
    datediff=$((epochcertdate-currentdate))
    state="OK"
  else
    state="EXPIRED"
    datediff=$((currentdate-epochcertdate))
  fi
  days=$((datediff/86400))
  certdate=`echo $cert | base64 -d | openssl x509 -noout -enddate| cut -d= -f2`
  printf "$format" "$state" "$days" "$name" "$certdate" "$namespace"
don
