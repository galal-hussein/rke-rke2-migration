
data "terraform_remote_state" "base" {
  backend = "local"

  config = {
    path = "../state/base.tfstate"
  }
}

data "terraform_remote_state" "network" {
  backend = "local"

  config = {
    path = "../state/network.tfstate"
  }
}

data "terraform_remote_state" "rancher_cluster" {
  backend = "local"

  config = {
    path = "../state/rancher-cluster.tfstate"
  }
}

data "aws_ami" "main" {
  most_recent = true
  owners      = [var.aws_ami_owner]

  filter {
    name   = "name"
    values = ["${var.aws_ami_prefix}*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "nodes" {
  source = "../../../modules/aws-nodes"

  node_name_prefix         = "nikkelma-mig-${data.terraform_remote_state.base.outputs.cluster_suffix}-"
  ami_id                   = data.aws_ami.main.id
  instance_type            = "t3a.xlarge"
  key_name                 = "nikkelma-main"
  subnet_id                = data.terraform_remote_state.network.outputs.subnet_id
  aio_security_group_id    = data.terraform_remote_state.network.outputs.rke2_aio_sg_id
  worker_security_group_id = data.terraform_remote_state.network.outputs.rke2_worker_sg_id
  registration_command     = data.terraform_remote_state.rancher_cluster.outputs.registration_command
  os_username              = "ec2-user"

  aio_count    = 3
  worker_count = 0
  use_all_ips  = true
}
