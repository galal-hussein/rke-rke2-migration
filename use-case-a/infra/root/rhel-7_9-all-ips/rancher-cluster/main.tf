
data "terraform_remote_state" "base" {
  backend = "local"

  config = {
    path = "../state/base.tfstate"
  }
}

module "cluster" {
  source = "../../../modules/rancher-cluster"

  cluster_name = "migration-${data.terraform_remote_state.base.outputs.cluster_suffix}"
}
