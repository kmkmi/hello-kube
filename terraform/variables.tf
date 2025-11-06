variable "cluster_name" {
  type        = string
}

variable "kubeconfig_path" {
  type        = string
}

variable "runnerdeployment_yaml_path" {
  type        = string
}

variable "github_token" {
  description = "GitHub Personal Access Token"
  type        = string
  sensitive   = true
}

variable "github_repo" {
  description = "GitHub Repository (username/repo)"
  type        = string
}

variable "runner_replicas" {
  type        = number
  default     = 2
}
