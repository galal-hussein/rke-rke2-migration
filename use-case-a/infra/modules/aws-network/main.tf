
resource "aws_vpc" "main" {
  cidr_block = "10.22.0.0/16"

  tags = merge(
    var.extra_tags,
    { "Name" = "${var.network_name}-vpc" }
  )
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.22.0.0/24"

  tags = merge(
    var.extra_tags,
    { "Name" = "${var.network_name}-subnet" }
  )
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.extra_tags,
    { "Name" = "${var.network_name}-igw" }
  )
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.extra_tags,
    { "Name" = "${var.network_name}-rt" }
  )
}

resource "aws_route" "main_igw" {
  route_table_id         = aws_route_table.main.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

# ==============================================================================
# RKE all-in-one security group
# ==============================================================================

resource "aws_security_group" "rke_aio" {
  name   = "${var.network_name}-sg-rke-aio"
  vpc_id = aws_vpc.main.id

  tags = var.extra_tags
}

resource "aws_security_group_rule" "rke_aio_egress_allow_all" {
  security_group_id = aws_security_group.rke_aio.id

  type        = "egress"
  protocol    = "all"
  from_port   = 0
  to_port     = 0
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "rke_aio_ingress_ssh" {
  security_group_id = aws_security_group.rke_aio.id

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "rke_aio_ingress_etcd" {
  security_group_id = aws_security_group.rke_aio.id

  type      = "ingress"
  protocol  = "tcp"
  from_port = 2379
  to_port   = 2380
  self      = true
}

resource "aws_security_group_rule" "rke_aio_ingress_canal_self" {
  security_group_id = aws_security_group.rke_aio.id

  type      = "ingress"
  protocol  = "udp"
  from_port = 8472
  to_port   = 8472
  self      = true
}

resource "aws_security_group_rule" "rke_aio_ingress_canal_worker" {
  security_group_id = aws_security_group.rke_aio.id

  type                     = "ingress"
  protocol                 = "udp"
  from_port                = 8472
  to_port                  = 8472
  source_security_group_id = aws_security_group.rke_worker.id
}

resource "aws_security_group_rule" "rke_aio_ingress_health_canal" {
  security_group_id = aws_security_group.rke_aio.id

  type      = "ingress"
  protocol  = "tcp"
  from_port = 9099
  to_port   = 9099
  self      = true
}

resource "aws_security_group_rule" "rke_aio_ingress_kubelet" {
  security_group_id = aws_security_group.rke_aio.id

  type      = "ingress"
  protocol  = "tcp"
  from_port = 10250
  to_port   = 10250
  self      = true
}

resource "aws_security_group_rule" "rke_aio_ingress_http" {
  security_group_id = aws_security_group.rke_aio.id

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 80
  to_port     = 80
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "rke_aio_ingress_https" {
  security_group_id = aws_security_group.rke_aio.id

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "rke_aio_ingress_k8s_api" {
  security_group_id = aws_security_group.rke_aio.id

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 6443
  to_port     = 6443
  cidr_blocks = ["0.0.0.0/0"]
}

# NOTE: NGINX Ingress Controller health check exposed to allow cloud load
# balancers to check Ingress Controller status
resource "aws_security_group_rule" "rke_aio_ingress_health_nginx_ingress" {
  security_group_id = aws_security_group.rke_aio.id

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 10254
  to_port     = 10254
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "rke_aio_ingress_node_port_tcp" {
  security_group_id = aws_security_group.rke_aio.id

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 30000
  to_port     = 32767
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "rke_aio_ingress_node_port_udp" {
  security_group_id = aws_security_group.rke_aio.id

  type        = "ingress"
  protocol    = "udp"
  from_port   = 30000
  to_port     = 32767
  cidr_blocks = ["0.0.0.0/0"]
}

# ==============================================================================
# RKE worker security group
# ==============================================================================

resource "aws_security_group" "rke_worker" {
  name   = "${var.network_name}-sg-rke-worker"
  vpc_id = aws_vpc.main.id

  tags = var.extra_tags
}

resource "aws_security_group_rule" "rke_worker_egress_allow_all" {
  security_group_id = aws_security_group.rke_worker.id

  type        = "egress"
  protocol    = "all"
  from_port   = 0
  to_port     = 0
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "rke_worker_ingress_canal_self" {
  security_group_id = aws_security_group.rke_worker.id

  type      = "ingress"
  protocol  = "udp"
  from_port = 8472
  to_port   = 8472
  self      = true
}

resource "aws_security_group_rule" "rke_worker_ingress_canal_worker" {
  security_group_id = aws_security_group.rke_worker.id

  type                     = "ingress"
  protocol                 = "udp"
  from_port                = 8472
  to_port                  = 8472
  source_security_group_id = aws_security_group.rke_aio.id
}

resource "aws_security_group_rule" "rke_worker_ingress_health_canal" {
  security_group_id = aws_security_group.rke_worker.id

  type      = "ingress"
  protocol  = "tcp"
  from_port = 9099
  to_port   = 9099
  self      = true
}

resource "aws_security_group_rule" "rke_worker_ingress_kubelet" {
  security_group_id = aws_security_group.rke_worker.id

  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 10250
  to_port                  = 10250
  source_security_group_id = aws_security_group.rke_aio.id
}

# NOTE: NGINX Ingress Controller health check exposed to allow cloud load
# balancers to check Ingress Controller status
resource "aws_security_group_rule" "rke_worker_ingress_health_nginx_ingress" {
  security_group_id = aws_security_group.rke_worker.id

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 10254
  to_port     = 10254
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "rke_worker_ingress_node_port_tcp" {
  security_group_id = aws_security_group.rke_worker.id

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 30000
  to_port     = 32767
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "rke_worker_ingress_node_port_udp" {
  security_group_id = aws_security_group.rke_worker.id

  type        = "ingress"
  protocol    = "udp"
  from_port   = 30000
  to_port     = 32767
  cidr_blocks = ["0.0.0.0/0"]
}

# ==============================================================================
# RKE2 all-in-one security group
# ==============================================================================

resource "aws_security_group" "rke2_aio" {
  name   = "${var.network_name}-sg-rke2-aio"
  vpc_id = aws_vpc.main.id

  tags = var.extra_tags
}

resource "aws_security_group_rule" "rke2_aio_egress_allow_all" {
  security_group_id = aws_security_group.rke2_aio.id

  type        = "egress"
  protocol    = "all"
  from_port   = 0
  to_port     = 0
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "rke2_aio_ingress_ssh" {
  security_group_id = aws_security_group.rke2_aio.id

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "rke2_aio_ingress_management_self" {
  security_group_id = aws_security_group.rke2_aio.id

  type      = "ingress"
  protocol  = "tcp"
  from_port = 9345
  to_port   = 9345
  self      = true
}

resource "aws_security_group_rule" "rke2_aio_ingress_management_worker" {
  security_group_id = aws_security_group.rke2_aio.id

  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 9345
  to_port                  = 9345
  source_security_group_id = aws_security_group.rke2_worker.id
}

resource "aws_security_group_rule" "rke2_aio_ingress_k8s_api" {
  security_group_id = aws_security_group.rke2_aio.id

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 6443
  to_port     = 6443
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "rke2_aio_ingress_canal_self" {
  security_group_id = aws_security_group.rke2_aio.id

  type      = "ingress"
  protocol  = "udp"
  from_port = 8472
  to_port   = 8472
  self      = true
}

resource "aws_security_group_rule" "rke2_aio_ingress_canal_worker" {
  security_group_id = aws_security_group.rke2_aio.id

  type                     = "ingress"
  protocol                 = "udp"
  from_port                = 8472
  to_port                  = 8472
  source_security_group_id = aws_security_group.rke2_worker.id
}

resource "aws_security_group_rule" "rke2_aio_ingress_kubelet_self" {
  security_group_id = aws_security_group.rke2_aio.id

  type      = "ingress"
  protocol  = "tcp"
  from_port = 10250
  to_port   = 10250
  self      = true
}

resource "aws_security_group_rule" "rke2_aio_ingress_kubelet_worker" {
  security_group_id = aws_security_group.rke2_aio.id

  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 10250
  to_port                  = 10250
  source_security_group_id = aws_security_group.rke2_worker.id
}

resource "aws_security_group_rule" "rke2_aio_ingress_etcd" {
  security_group_id = aws_security_group.rke2_aio.id

  type      = "ingress"
  protocol  = "tcp"
  from_port = 2379
  to_port   = 2380
  self      = true
}

resource "aws_security_group_rule" "rke2_aio_ingress_node_port" {
  security_group_id = aws_security_group.rke2_aio.id

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 30000
  to_port     = 32767
  cidr_blocks = ["0.0.0.0/0"]
}

# ==============================================================================
# RKE2 worker security group
# ==============================================================================

resource "aws_security_group" "rke2_worker" {
  name   = "${var.network_name}-sg-rke2-worker"
  vpc_id = aws_vpc.main.id

  tags = var.extra_tags
}

resource "aws_security_group_rule" "rke2_worker_egress_allow_all" {
  security_group_id = aws_security_group.rke2_worker.id

  type        = "egress"
  protocol    = "all"
  from_port   = 0
  to_port     = 0
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "rke2_worker_ingress_ssh" {
  security_group_id = aws_security_group.rke2_worker.id

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "rke2_worker_ingress_canal_self" {
  security_group_id = aws_security_group.rke2_worker.id

  type      = "ingress"
  protocol  = "udp"
  from_port = 8472
  to_port   = 8472
  self      = true
}

resource "aws_security_group_rule" "rke2_worker_ingress_canal_worker" {
  security_group_id = aws_security_group.rke2_worker.id

  type                     = "ingress"
  protocol                 = "udp"
  from_port                = 8472
  to_port                  = 8472
  source_security_group_id = aws_security_group.rke2_aio.id
}

resource "aws_security_group_rule" "rke2_worker_ingress_kubelet_self" {
  security_group_id = aws_security_group.rke2_worker.id

  type      = "ingress"
  protocol  = "tcp"
  from_port = 10250
  to_port   = 10250
  self      = true
}

resource "aws_security_group_rule" "rke2_worker_ingress_kubelet_worker" {
  security_group_id = aws_security_group.rke2_worker.id

  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 10250
  to_port                  = 10250
  source_security_group_id = aws_security_group.rke2_aio.id
}

resource "aws_security_group_rule" "rke2_worker_ingress_node_port" {
  security_group_id = aws_security_group.rke2_worker.id

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 30000
  to_port     = 32767
  cidr_blocks = ["0.0.0.0/0"]
}
