output "aio_public_ips" {
  value = aws_instance.aio[*].public_ip
}

output "aio_private_ips" {
  value = aws_instance.aio[*].private_ip
}

output "worker_public_ips" {
  value = aws_instance.worker[*].public_ip
}

output "worker_private_ips" {
  value = aws_instance.worker[*].private_ip
}
