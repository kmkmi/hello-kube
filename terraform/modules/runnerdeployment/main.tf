terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

locals {
  runnerdeployment_yaml = templatefile(var.runnerdeployment_yaml_path, {
    runner_replicas = var.runner_replicas
    github_repo     = var.github_repo
  })
}

resource "null_resource" "runnerdeployment_apply" {
  provisioner "local-exec" {
    command = <<EOT
kubectl --kubeconfig ${var.kubeconfig_path} apply -f - <<< "${local.runnerdeployment_yaml}"
EOT
    interpreter = ["bash", "-c"]  
  }
}
