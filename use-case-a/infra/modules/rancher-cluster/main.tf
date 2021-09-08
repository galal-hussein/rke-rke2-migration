
resource "rancher2_cluster" "main" {
  name = var.cluster_name

  rke_config {
    network {
      plugin = "canal"
    }
    kubernetes_version = "v1.19.10-rancher1-1"
  }
}
