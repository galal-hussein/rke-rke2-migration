# RKE to RKE2 in-place migration outline

A Custom cluster in Rancher (using RKE under the hood) with three all-in-one nodes needs to be moved to RKE2 with minimal downtime of the workloads in the cluster, and minimizing k8s API downtime as well.
A high-level summary of the approach is detailed here to help give insight into the current targeted process for this upgrade/migration.

## Outline

1. Prerequisite upgrades
    1. Upgrade Rancher to v2.5.8
    2. Upgrade RKE of target cluster to 1.20.6-rancher1-1
2. Fetch cluster state out of Rancher `Cluster` object 
3. Remove cattle agents from downstream cluster 
    - Ensures Rancher doesn't try to auto upgrade any nodes when detected as an Imported RKE2 cluster
4. Edit Rancher `Cluster` object to be an Imported cluster instead of a Custom cluster
5. Use RKE CLI to convert 3 all-in-one (AIO) node cluster to a 1 AIO, 2 worker architecture
6. Perform etcd backup using RKE CLI; run `migration-agent` (downloaded from github - <https://github.com/rancher/migration-agent>) on AIO node using this snapshot
7. Install RKE2 on AIO node; stop Docker on AIO node; start RKE2 on AIO node
8. Run `migration-agent` on each worker
9. On each worker, one at a time...
    1. Install RKE2
    2. Stop Docker
    3. Start RKE2 as `server`
10. Run Rancher `kubectl apply -f ...` Imported cluster command on healthy cluster

### Expected downtime

- Workload containers will only restart when Docker is stopped before RKE2 is started on a node (step 9)
- The k8s API endpoint will be fully unavailable between when Docker is stopped on the AIO node and when RKE2 brings up its API server (step 7)
- The Rancher-proxied API endpoint will be unavailable from when the agents are removed (step 3) to when the Rancher Import command is run (step 10)

### RKE CLI Conversion

To allow changing the architecture of the cluster (number and types of nodes), we need to pull the RKE `cluster.yaml` config from the Rancher `Cluster` object to then use with the RKE CLI.
This requires custom parsing using <https://github.com/nikkelma/rke-rke2-migration/tree/main/rke-cluster-parser> and some massaging of the `Cluster` object JSON using `jq`.

