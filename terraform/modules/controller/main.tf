terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Deploying cert-manager
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = var.cert_manager_version

  set {
    name  = "installCRDs"
    value = true
  }
}

# Deploying actions-runner-controller (ARC)
resource "helm_release" "gha_controller" {
  name             = "actions-runner-controller"
  repository       = "https://actions-runner-controller.github.io/actions-runner-controller"
  chart            = "actions-runner-controller"
  namespace        = "actions-runner-system"
  create_namespace = true
  version          = "0.23.7"

  replace      = true
  force_update = true

  depends_on = [helm_release.cert_manager]

  set {
    name  = "authSecret.create"
    value = true
  }

  set {
    name  = "authSecret.name"
    value = "controller-manager"
  }

  set {
    name  = "authSecret.github_token"
    value = var.github_token
  }

    set {
    name  = "installCRDs"
    value = "true"
  }

  # set {
  #   name  = "runnerIdentity.type"
  #   value = "oidc"
  # }

  # set {
  #   name  = "runnerIdentity.oidcClientID"
  #   value = "sts.example.com"
  # }

  # set {
  #   name  = "runnerIdentity.oidcIssuerURL"
  #   value = "https://token.actions.githubusercontent.com"
  # }

  set {
    name  = "webhook.create"
    value = "true"
  }

  set {
  name  = "githubWebhookServer.enabled"
  value = "true"
  }

  wait         = true  
  cleanup_on_fail = true
}


# Waiting ARC Webhook until available 
resource "null_resource" "wait_for_arc_webhook" {
  depends_on = [helm_release.gha_controller]

  provisioner "local-exec" {
    command = <<EOT
      echo "⏳ Waiting for ARC webhook..."
      for i in {1..30}; do
        kubectl -n actions-runner-system get deploy actions-runner-controller-github-webhook-server --kubeconfig=${var.kubeconfig_path} &>/dev/null || { echo "waiting... ($i/30)"; sleep 5; continue; }
        kubectl -n actions-runner-system wait --for=condition=available deployment/actions-runner-controller-github-webhook-server --timeout=120s --kubeconfig=${var.kubeconfig_path} && break
        sleep 5
      done
    EOT
  }
}

