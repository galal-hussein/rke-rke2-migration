
locals {
  aio_userdata_file    = var.use_all_ips ? "files/userdata_all-ips_aio.sh.tmpl" : "files/userdata_internal-ips_aio.sh.tmpl"
  worker_userdata_file = var.use_all_ips ? "files/userdata_all-ips_worker.sh.tmpl" : "files/userdata_internal-ips_worker.sh.tmpl"
}

resource "tls_private_key" "nodes_shared" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_instance" "aio" {
  count = var.aio_count

  ami           = var.ami_id
  instance_type = var.instance_type

  key_name                    = var.key_name
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.aio_security_group_id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.root_disk_size
  }

  user_data = templatefile(
    abspath(join("/", [path.module, local.aio_userdata_file])),
    {
      os_username         = var.os_username
      register_command    = var.registration_command
      ssh_private_key_b64 = base64encode(tls_private_key.nodes_shared.private_key_pem)
      ssh_public_key_b64  = base64encode(tls_private_key.nodes_shared.public_key_openssh)
    }
  )

  tags = merge(
    var.extra_tags,
    { "Name" = "${var.node_name_prefix}aio-${count.index}" }
  )
}

resource "aws_instance" "worker" {
  count = var.worker_count

  ami           = var.ami_id
  instance_type = var.instance_type

  key_name                    = var.key_name
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.worker_security_group_id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.root_disk_size
  }

  user_data = templatefile(
    abspath(join("/", [path.module, local.worker_userdata_file])),
    {
      os_username         = var.os_username
      register_command    = var.registration_command
      ssh_private_key_b64 = base64encode(tls_private_key.nodes_shared.private_key_pem)
      ssh_public_key_b64  = base64encode(tls_private_key.nodes_shared.public_key_openssh)
    }
  )

  tags = merge(
    var.extra_tags,
    { "Name" = "${var.node_name_prefix}worker-${count.index}" }
  )
}
