output "aio_public_ips" {
  value = module.nodes.aio_public_ips
}

output "aio_private_ips" {
  value = module.nodes.aio_private_ips
}

output "worker_public_ips" {
  value = module.nodes.worker_public_ips
}

output "worker_private_ips" {
  value = module.nodes.worker_private_ips
}
