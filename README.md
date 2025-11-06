# Hello-kube
Self-hosted GitHub Actions Runner를 Kubernetes(Kind) 환경에 배포하는 프로젝트입니다.

Terraform을 이용해 클러스터 구성부터 Runner 배포까지 과정을 자동화하고

Github Actions Wokrflow를 트리거하여 실행합니다.

## Installation
- git에서 source를 내려 받습니다.

git https://git-scm.com/install/

`git clone https://github.com/kmkmi/hello-kube.git`

- terraform을 이용해 배포하기 위해 terraform, docker 그리고 bash가 설치된 환경에서 진행합니다.

terraform https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli

docker https://docs.docker.com/engine/install/

- 배포 검증을 위해 kubectl과 kind를 사용합니다.

kubectl https://kubernetes.io/ko/docs/tasks/tools/

kind https://kind.sigs.k8s.io/docs/user/quick-start/#installation

---

## Deployment

### terraform modules

```
terraform
├── main.tf
├── terraform.tfvars
├── variables.tf
└── modules
     ├── controller
     │   ├── main.tf
     │   └── variables.tf
     ├── kind
     │   ├── main.tf
     │   ├── outputs.tf
     │   └── variables.tf
     └── runnerdeployment
          ├── main.tf
          ├── runner-deployment.yaml
          └── variables.tf
```

terraform을 사용하여 각 모듈 별 배포 수행

- root : Run each module
    - kind : Create Kind cluster with OIDC patched API server
    - controller : Deploy cert-manager & GitHub Actions Runner Controller
    - runnerdeployment : Deploy GitHub Actions Runners using RunnerDeployment

### How to deploy

- terraform.tfvars example

```yaml
cluster_name = "kind-arc"
kubeconfig_path = "kubeconfig.yaml"
runnerdeployment_yaml_path = "modules/runnerdeployment/runner-deployment.yaml"
github_token      = $GITHUB_PAT
github_repo = "kmkmi/hello-kube"
runner_replicas = 2

```

<details>
<summary>Generate a Personal Access Token (PAT) for ARC to authenticate with GitHub.(https://github.com/settings/tokens/new)</summary>
    
    Login to your GitHub account and Navigate to "Create new Token(https://github.com/settings/tokens/new)."
    Select repo.
    Click Generate Token and then copy the token locally ( we’ll need it later).
    
</details>

```bash
# bash(e.g. git bash)
# terraform apply를 bash에서 실행해야 합니다.

cd terraform/
terraform init
terraform apply -auto-approve
```

### Verify Deployment

```bash
$ kind get clusters
kind-arc

$ kubectl get po -n actions-runner-system
NAME                                         READY   STATUS    RESTARTS   AGE
actions-runner-controller-559597c7d5-2hkhs   2/2     Running   0          3m45s
example-runnerdeploy-n6pbp-8ljm8             2/2     Running   0          2m20s
example-runnerdeploy-n6pbp-qpxlc             2/2     Running   0          2m11s

$ kubectl get runnerdeployment -n actions-runner-system
NAME                   ENTERPRISE   ORGANIZATION   REPOSITORY         GROUP   LABELS   DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
example-runnerdeploy                               kmkmi/hello-kube                    2         2         2            2           5m31s

$ kubectl get runner -n actions-runner-system
NAME                               ENTERPRISE   ORGANIZATION   REPOSITORY         GROUP   LABELS   STATUS    MESSAGE   WF REPO   WF RUN   AGE
example-runnerdeploy-n6pbp-8ljm8                               kmkmi/hello-kube                    Running                                3m59s
example-runnerdeploy-n6pbp-qpxlc                               kmkmi/hello-kube                    Running                                3m50s

```

---

## Wokrflows

kmkmi/hello-kube repository main branch에 push하거나

repo 페이지 Actions 탭의 Run workflow를 실행하여 workflow를 실행합니다.

### hello-kube

hello-kube go 프로세스를 빌드하고 실행합니다.

hello-kube는 main.go 하나의 소스로 구현된 프로그램으로 "Hello world"를 stdout에 출력하는 hello pod을 생성하고 hello pod이 종료된 후 종료됩니다.

hello-kube는 K8s API Server에 Github OIDC JWT를 사용해 인증합니다.

### docker-build

hello-kube golang source를 Dockerfile을 사용해 docker build하고

Dock Hub의 https://hub.docker.com/repository/docker/fhdj4564/hello-kube Repository에 push 합니다.

---

## Note
- 컴퓨팅 리소스나 디스크 용량이 작은 경우 runner 실행에 문제 발생할 수 있어 2core 20GB 이상 환경에서 배포 권장
- 다음 환경에서 테스트 완료
    - Windows 11 / git bash / X86_64
    - windows 11 / WSL ubuntu 24.04 LTS / X86_64
    - GCP / ubuntu 24.04 LTS / X86_64