
output "cluster_id" {
  value = rancher2_cluster.main.id
}

output "registration_command" {
  value = rancher2_cluster.main.cluster_registration_token[0].node_command
}
