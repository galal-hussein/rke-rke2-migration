data "terraform_remote_state" "base" {
  backend = "local"

  config = {
    path = "../state/base.tfstate"
  }
}

module "aws_network" {
  source = "../../../modules/aws-network"

  network_name = "mig-${data.terraform_remote_state.base.outputs.cluster_suffix}"
  extra_tags = {
    "Project" = "mig-${data.terraform_remote_state.base.outputs.cluster_suffix}"
  }
}
