output "cluster_name" {
  value       = kind_cluster.this.name
}

output "kubeconfig" {
  value       = kind_cluster.this.kubeconfig
  sensitive   = true
}

output "kubeconfig_path" {
  value       = local_file.kubeconfig.filename
}

output "cluster_endpoint" {
  value       = kind_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  value       = kind_cluster.this.cluster_ca_certificate
}

output "cluster_client_certificate" {
  value       = kind_cluster.this.client_certificate
}

output "cluster_client_key" {
  value       = kind_cluster.this.client_key
}
