variable "cert_manager_version" {
  type    = string
  default = "v1.8.2"
}

variable "github_token" {
  description = "GitHub Personal Access Token"
  type        = string
  sensitive   = true
}

variable "kubeconfig_path" {
  type        = string
}
