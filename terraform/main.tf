terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
  }
}

locals {
  kubeconfig_path =  abspath("${path.root}/${var.kubeconfig_path}")
  runnerdeployment_yaml_path = abspath("${path.root}/${var.runnerdeployment_yaml_path}")
}

# 1. Kind module
# Create Kind cluster with OIDC patched API server
module "kind" {
  source = "./modules/kind"
  
  cluster_name = var.cluster_name
  kubeconfig_path = local.kubeconfig_path
}

provider "kubernetes" {
  host                   = module.kind.cluster_endpoint
  cluster_ca_certificate = module.kind.cluster_ca_certificate
  client_certificate     = module.kind.cluster_client_certificate
  client_key             = module.kind.cluster_client_key
}

provider "helm" {
  kubernetes {
  host                   = module.kind.cluster_endpoint
  cluster_ca_certificate = module.kind.cluster_ca_certificate
  client_certificate     = module.kind.cluster_client_certificate
  client_key             = module.kind.cluster_client_key
  }
}


# 2. Controller module
# Deploy cert-manager & GitHub Actions Runner Controller 
module "controller" {
  source = "./modules/controller"
  
  depends_on = [module.kind]
  kubeconfig_path = local.kubeconfig_path
  github_token = var.github_token
}

# 3. RunnerDeployment module
# Deploy GitHub Actions Runners using RunnerDeployment
module "runnerdeployment" {
  source = "./modules/runnerdeployment"
  
  depends_on = [module.controller]
  runnerdeployment_yaml_path = local.runnerdeployment_yaml_path
  kubeconfig_path = local.kubeconfig_path
  runner_replicas = var.runner_replicas
  github_repo = var.github_repo
}
