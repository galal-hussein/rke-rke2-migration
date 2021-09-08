# Cluster Migration Scripts

## Version 01 (`v01`)

Version 01 assumes the following:
- the initial cluster is a three-node all-in-one (AIO) cluster
- one node will be chosen (by IP) to remain an AIO cluster and get migrated to RKE2 first, followed by the other nodes
- a kubeconfig for the Rancher `local` cluster can be provided and will be accessible on disk
- all nodes in the original RKE cluster are accessible via SSH from the node where this script is run
