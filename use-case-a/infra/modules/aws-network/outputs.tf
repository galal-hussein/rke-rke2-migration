output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_id" {
  value = aws_subnet.main.id
}

output "rke_aio_sg_id" {
  value = aws_security_group.rke_aio.id
}

output "rke_worker_sg_id" {
  value = aws_security_group.rke_worker.id
}

output "rke2_aio_sg_id" {
  value = aws_security_group.rke2_aio.id
}

output "rke2_worker_sg_id" {
  value = aws_security_group.rke2_worker.id
}
