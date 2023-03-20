#!/bin/bash
while [ -z ${REGISTRY_FQDN} ]
  do
    read -p "Please provide FQDN for the image registry (hint: default-route-openshift-image-registry.apps.cluster.example.com): " REGISTRY_FQDN
done
while [ -z ${ORG_ID} ]
  do 
    read -p "Please provide Organization ID number: " ORG_ID
done

while [ -z ${ACTIVATION_KEY} ]
  do
    read -p "Please provide activation key: " ACTIVATION_KEY
done

podman build --no-cache --arch=amd64 --build-arg ORG_ID="${ORG_ID}" --build-arg ACTIVATION_KEY="${ACTIVATION_KEY}" -t ${REGISTRY_FQDN}/default/cssr-init .
