output "vpc_id" {
  value = module.aws_network.vpc_id
}

output "subnet_id" {
  value = module.aws_network.subnet_id
}

output "rke_aio_sg_id" {
  value = module.aws_network.rke_aio_sg_id
}

output "rke_worker_sg_id" {
  value = module.aws_network.rke_worker_sg_id
}

output "rke2_aio_sg_id" {
  value = module.aws_network.rke2_aio_sg_id
}

output "rke2_worker_sg_id" {
  value = module.aws_network.rke2_worker_sg_id
}
