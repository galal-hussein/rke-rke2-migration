# Use Case A

- Cluster type: Custom
- OS: RHEL 7.9
- RKE version: 1.19.x
- Docker version: 20.10
- Cluster architecture:
  - 3 all-in-one (AIO) nodes (all roles)

## `infra` folder

Contains terraform code used to create a fresh testing environment used for running through the migration process.

These modules currently assume a Rancher v2.5.8 server exists and an API key allowing creating + updating `Cluster` API objects is on hand.

Resources created by the root modules include...
- random string used to differentiate across migration attempts ("base" module)
- AWS VPC, subnets, and security groups to ensure network rule migrations are known and tested
- Rancher `Cluster` API object (Custom cluster)
- AWS EC2 instances, either AIO or worker nodes, registered into the created Rancher Custom cluster

To create the infrastructure contained in a specific folder in `root`:
1. Change to `infra/root/folder` (e.g.) `cd ./infra/root/rhel-7_9-all-ips`
1. Copy all `.tfvars.example` files in the top level folder, renaming the copies to `.tfvars`
1. Edit `.tfvars` as needed
    - comment AWS creds if using CLI authentication
    - change region if wanted
    - uncomment AMI owner edit if using AWS GovCloud
1. Run `create.sh` in the folder
    > _**NOTE:**_ only run this script as `./create.sh` as it assumes `$(pwd)/*.tfvars` exist and contain relevant terraform variable values.

To remove the infrastructure contained in a specific folder in `root`:
1. Change to `infra/root/folder` (e.g.) `cd ./infra/root/rhel-7_9-all-ips`
1. Run `destroy.sh` in the folder
    > _**NOTE:**_ only run this script as `./destroy.sh` as it assumes `$(pwd)/*.tfvars` exist and contain relevant terraform variable values.

## `notes` folder

Contains any notes developed for this use case - overall outline, as requested by end customer, as well as step-by-step processes (instead of 100% scripted processes)

## `scripts` folder

Contains fully automated migration processes, using CLI flags and files on disk to pass in any configuration or parameters needed to perform a specific section of the overall migration process.
