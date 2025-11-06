terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.4"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# Create kind cluster
resource "kind_cluster" "this" {
  name           = var.cluster_name
  wait_for_ready = true
}

resource "null_resource" "patch_oidc" {
  depends_on = [kind_cluster.this]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = <<-EOT
CONTAINER="${var.cluster_name}-control-plane"

# kube-apiserver backup
docker exec "$CONTAINER" cp /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/kube-apiserver.yaml.backup

# OIDC setting patch using sed 
docker exec "$CONTAINER" sh -c "sed -i '/    - kube-apiserver/a\    - --oidc-issuer-url=https://token.actions.githubusercontent.com\n    - --oidc-client-id=sts.example.com\n    - --oidc-username-claim=sub\n    - --oidc-groups-claim=repository' /etc/kubernetes/manifests/kube-apiserver.yaml"
EOT
  }
}


resource "null_resource" "wait_api_server" {
  depends_on = [null_resource.patch_oidc]

  provisioner "local-exec" {
    command = <<EOT
MAX_RETRIES=60
RETRY=0
KUBECONFIG_PATH="${var.kubeconfig_path}"

# Wait kubeconfig
while [ ! -f "$KUBECONFIG_PATH" ]; do
    echo "Waiting for kubeconfig file..."
    sleep 2
    RETRY=$((RETRY+1))
    if [ $RETRY -ge $MAX_RETRIES ]; then
        echo "Timeout waiting for kubeconfig file"
        exit 1
    fi
done

# Wait API server Reachable
RETRY=0
while true; do
    kubectl --kubeconfig="$KUBECONFIG_PATH" get nodes >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "API server and nodes are reachable"
        break
    fi
    echo "Waiting for API server..."
    sleep 5
    RETRY=$((RETRY+1))
    if [ $RETRY -ge $MAX_RETRIES ]; then
        echo "Timeout waiting for API server"
        exit 1
    fi
done

# Wait nodes Ready
kubectl --kubeconfig="$KUBECONFIG_PATH" wait --for=condition=Ready nodes --all --timeout=300s
kubectl --kubeconfig="$KUBECONFIG_PATH" wait --for=condition=Ready pods --all -n kube-system --timeout=300s
EOT
    interpreter = ["bash", "-c"]
  }
}


# Saving kubeconfig to file
resource "local_file" "kubeconfig" {
  content  = kind_cluster.this.kubeconfig
  filename = var.kubeconfig_path
}

resource "kubernetes_cluster_role_binding" "github_actions" {
  depends_on = [local_file.kubeconfig] 

  metadata {
    name = "github-actions-binding"
  }

  subject {
    kind = "User"
    name = "repo:kmkmi/hello-kube:ref:refs/heads/main"
  }

  role_ref {
    kind     = "ClusterRole"
    name     = "cluster-admin"
    api_group = "rbac.authorization.k8s.io"
  }
}
