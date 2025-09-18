#!/bin/bash
export ENVIRONMENT=$(kubectl config view --minify --output 'jsonpath={.clusters[0].name}'| awk -F'/' '{print $2}' | awk -F'-' '{print $3}')

#####################################################################################
# Namespace
#####################################################################################
kubectl create ns esp-apim-${ENVIRONMENT} 
kubectl create ns esp-fo-${ENVIRONMENT}  
kubectl create ns esp-hcas-${ENVIRONMENT}
kubectl create ns esp-hims-${ENVIRONMENT}
kubectl create ns esp-hpas-${ENVIRONMENT}
kubectl create ns esp-if-${ENVIRONMENT}     
