## Name
cSSR on OpenShift

## Disclaimer
This is a pure PROOF OF CONCEPT work.

## Description
The purpose of this project is to make Juniper's cSSR (Containerized Session Smart Router) appliance running on the top of OpenShift.

## Requirements
1. The following Operators are installed and configured
    1. SR-IOV Network Operator
    2. OpenShift Data Foundation

2. Registry with external route
3. Privileged ServiceAccount
4. TBC

## Usage
1. Configure and enable HugePages on the nodes - [example](05-master-kernelarg-hugepages.machineconfig.yaml)
2. Create the namespace where cSSR container will run.
   ```
   $ export CSSR_NAMESPACE=cssr-test
   $ oc new-project ${CSSR_NAMESPACE}
   ```
3. Create extra ServiceAccount and grant it with _privileged_ SCC 
   ```
   $ oc create sa privileged
   serviceaccount/privileged
   $ oc adm policy add-scc-to-user privileged -z privileged
   clusterrole.rbac.authorization.k8s.io/system:openshift:scc:privileged added: "privileged"
   ```
4. Ensure ServiceAccounts from the namespace will be able to pull container images from _default_ namespace
   ```
   $ oc policy add-role-to-group system:image-puller system:serviceaccounts:${CSSR_NAMESPACE} --namespace=default
   ```
5. Configure and create required _SriovNetworkNodePolicy_ - [example](sriov-operator)
6. Create and upload to OpenShift's internal registry _cssr-init_ container - [cssr-init](cssr-init). It will prepopulate modules and kernel sources on the modules volume.
7. Create modules PVC - this is where modules and kernel sources will be shared with the containers, instead of directly accessing local node's filesystem [cssr-modules-volume.yaml](cssr-modules-volume.yaml)
8. Review, modify accordingly and apply cssr-test StatefulSet [cssr-statefulset.yaml](cssr-statefulset.yaml). You should particularly pay attention to _spec.template.metadata.annotations k8s.v1.cni.cncf.io/networks_ to attach the right networks to the pod.


## Rationale
Out of the box Juniper's cSSR requires two extra DPDK modules which are not shipped by Red Hat. These are *rte_kni.ko* and *igb_uio.ko*.
Due to the nature of Red Hat CoreOS it isn't possible or at least advised to tinker with node's filesystem as it is immutable.
Therefore we need a way to build the required modules against currently used kernel version and keep it updated while kernel version changes.

Juniper provides following two container images:
1. quay.io/juniper-128t/kmod-builder-51
2. quay.io/juniper-128t/128t-5121


The first one is a module builder which can be used to build the required *rte_kni.ko* and *igb_uio.ko* modules. It requires kernel modules from `/usr/lib/modules/$(uname -r)` and kernel headers from `/usr/src/kernels/$(uname -r)`.
It is [init-modules's](cssr-statefulset.yaml#L26-47) *initContainer* job to populate these two directories before *kmod-builder* will start. They will be loaded to [modules volume](cssr-modules-volume.yaml) which is shared between all cSSR pods running within the same StatefulSet.
*Please note: there is an assumption made that all OpenShift nodes have the same kernel version.*

The next step is to put the default configuration files from cSSR image to [cssr-data volume](cssr-statefulset.yaml#L140-148), so it will persist across cSSR container restarts/deletions until it will be manually removed by operator.
This is done with [cssr-init-data](cssr-statefulset.yaml#L48-61) *initContainer*.  
Currently the following dictionaries are being copied:
- /var/128technology
- /etc/128t-monitoring
*Please note: cssr-data volume is persistent and unique for each cSSR running pod. By default we get only one but if we scale it out, new volume will be created and configured for the new cSSR pod.*
  
At this stage we can build the missing DPDK modules inside of another initContainer [cssr-kmod-builder](cssr-statefulset.yaml#L62-81).
  
Once the three above steps are done with initContainers, the actual [cSSR container](cssr-statefulset.yaml#L83-108) is being started.

## Authors and acknowledgment
Rafal Szmigiel <rafal_at_redhat_dot_com>

