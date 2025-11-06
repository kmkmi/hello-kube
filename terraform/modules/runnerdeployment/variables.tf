variable "kubeconfig_path" {
  type        = string
}

variable "runner_replicas" {
  type        = number
  default     = 2
}

variable "github_repo" {
  description = "GitHub Repository(username/repo)"
  type        = string
}

variable "runnerdeployment_yaml_path" {
  type = string
}