# AWS EKS delivery guide

This guide explains the starter already on `practice/devops-from-scratch` and gives you a safe order for learning it. The goal is to understand each link in the delivery chain, then rebuild or improve it in a short-lived exercise branch.

> **Pause before AWS apply.** Terraform creates billable EKS control-plane, EC2, NAT gateway, ECR, and load-balancer resources. Read the plan and the cleanup section before applying it. No command in the container or Helm labs creates AWS resources.

## 1. What the system does

```text
source + Dockerfiles
        │ pull request: build checks; branch push: build and publish
        ▼
GitHub Actions ──OIDC──> ECR (immutable commit-SHA image tags)
                                 │
                         Helm chart in Git
                                 │ merged image-promotion PR
                                 ▼
                         Argo CD on EKS
                                 │
                     frontend -> gRPC services -> Redis
```

The application has eleven core services written in several languages. The services communicate over gRPC. The default cart store is Redis, so the default flow does not need MySQL or RDS. The optional shopping assistant and Google Cloud deployment integrations are outside this AWS exercise.

## 2. Repository map

| Path | What it owns | What to inspect first |
|---|---|---|
| `src/<service>/` | Service code and its Docker build context | Service README, dependency file, listening port |
| `src/cartservice/src/` | Cart service Docker build context | It is nested one level deeper than the other contexts |
| `deploy/helm/online-boutique/` | Deployments, Services, Redis, image tag and basic resources | `values.yaml`, then `templates/services.yaml` |
| `infra/terraform/` | VPC, EKS, ECR, GitHub OIDC publishing role | `variables.tf`, `main.tf`, then `outputs.tf` |
| `.github/workflows/app.yml` | PR builds and branch image publishing/promotion | Triggers, permissions, matrix, image tag |
| `.github/workflows/terraform.yml` | Terraform formatting and validation on changed infrastructure | Backend is intentionally disabled in CI |
| `deploy/argocd/online-boutique.yaml` | Argo CD Application watching this repository branch | Repository URL, revision, chart path |
| `docs/devops-learning-roadmap.md` | Ordered practice labs and completion evidence | Use this to track what you have completed |

### Service ports and build contexts

These are the ports used by the current Helm values. A Service port is the in-cluster destination; the frontend Service listens on port 80 and forwards to the frontend container on 8080.

| Service | Docker build context | Container port | Role |
|---|---|---:|---|
| `adservice` | `src/adservice` | 9555 | Ads gRPC API |
| `cartservice` | `src/cartservice/src` | 7070 | Cart gRPC API; uses Redis |
| `checkoutservice` | `src/checkoutservice` | 5050 | Checkout orchestration |
| `currencyservice` | `src/currencyservice` | 7000 | Currency conversion |
| `emailservice` | `src/emailservice` | 8080 | Order email demo |
| `frontend` | `src/frontend` | 8080 | Store web interface; Kubernetes Service port 80 |
| `loadgenerator` | `src/loadgenerator` | none | Generates browser traffic; does not expose a Service |
| `paymentservice` | `src/paymentservice` | 50051 | Payment gRPC API |
| `productcatalogservice` | `src/productcatalogservice` | 3550 | Product catalog gRPC API |
| `recommendationservice` | `src/recommendationservice` | 8080 | Product recommendation gRPC API |
| `shippingservice` | `src/shippingservice` | 50051 | Shipping quote gRPC API |
| `redis-cart` | Redis image from `values.yaml` | 6379 | Demo cart state store |

The Dockerfiles are from the upstream application project. Read them and their `.dockerignore` files before changing language-specific build details.

## 3. First lab: build and inspect images locally

This lab needs Git and Docker; it does not need AWS credentials, Kubernetes, or a GitHub token.

From the repository root, build one service first. The product catalog is a good first target because it has no downstream service dependency:

```bash
docker build \
  --file src/productcatalogservice/Dockerfile \
  --tag online-boutique/productcatalogservice:local \
  src/productcatalogservice
```

Check that the image exists and inspect its configured metadata:

```bash
docker image ls online-boutique/productcatalogservice
docker image inspect online-boutique/productcatalogservice:local
docker history online-boutique/productcatalogservice:local
```

Then build the cart image. Notice that its build context and Dockerfile are nested:

```bash
docker build \
  --file src/cartservice/src/Dockerfile \
  --tag online-boutique/cartservice:local \
  src/cartservice/src
```

Build the other services using the context table above. For each image, answer these questions in your notes:

1. Which files are copied before dependencies are installed, and why?
2. Which stage compiles or packages the service? Which stage runs it?
3. What is the final image's entrypoint and user?
4. Which files are excluded by `.dockerignore`?
5. Which port and environment variables does the service need?

You can run the product catalog container to observe startup:

```bash
docker run --rm --name productcatalog-local \
  --publish 3550:3550 \
  --env PORT=3550 \
  online-boutique/productcatalogservice:local
```

Stop it with `Ctrl-C`. This confirms the process can start; it does **not** prove checkout or the whole store works. Most services need other gRPC services, and cart also needs Redis.

**Checkpoint:** you can build and inspect at least one image, explain its context and layers, and describe why running one gRPC service is not an end-to-end app test.

## 4. Second lab: understand Kubernetes through Helm output

You can render the chart without a cluster. First inspect the chart, then run:

```bash
helm lint deploy/helm/online-boutique
helm template online-boutique deploy/helm/online-boutique \
  --namespace online-boutique \
  --set global.awsAccountId=123456789012 \
  --set global.awsRegion=us-east-1 \
  --set global.imageTag=example-sha
```

The account ID and tag above are examples used only to render text. Rendering does not contact AWS or create resources. In the output, find:

- one Deployment per service and one Redis Deployment;
- a ClusterIP Service for each gRPC service;
- a frontend Service of type `LoadBalancer` on Service port 80;
- the `REDIS_ADDR` setting for cart and service-address environment variables for callers;
- TCP readiness/liveness probes and resource requests/limits.

The chart is intentionally small. It has no TLS, autoscaling, persistent Redis, network policies, or production security context. Treat those as exercises after you understand the generated resources.

**Checkpoint:** you can trace a frontend request to its service DNS name, explain the difference between a Pod, Deployment, and Service, and identify which component exposes the store externally.

## 5. Third lab: prepare Terraform safely

### Prerequisites

- An AWS account and a named AWS CLI profile with permission to create the resources in `infra/terraform/`.
- Terraform 1.10 or newer, AWS CLI, `kubectl`, Helm, Docker, and Git.
- A fork you control. The provided GitHub workflow is configured for `practice/devops-from-scratch`.
- A versioned, encrypted, private S3 bucket dedicated to Terraform state.

Check that your AWS CLI identity is the one you intend to use:

```bash
aws sts get-caller-identity
aws configure list
```

Do not paste AWS credentials into `.tf`, `terraform.tfvars`, GitHub files, or this guide. Terraform authenticates through the AWS CLI credential chain.

### Create the state bucket before initializing Terraform

The S3 backend bucket must exist before `terraform init`. Create a dedicated bucket in the same region you plan to use, then enable bucket versioning, default encryption, and all public-access blocks. Keep ownership of this bucket separate from the EKS stack so `terraform destroy` does not delete its state.

Copy the example backend configuration and fill in your bucket name and region:

```bash
cd infra/terraform
cp backend.hcl.example backend.hcl
```

`backend.hcl` is ignored by Git. Never commit the real bucket details if your repository policy treats them as sensitive.

### Set your input values

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

- `aws_region`: the region for the VPC, EKS, and ECR;
- `cluster_version`: a Kubernetes version currently offered by EKS in that region; the example is only a snapshot;
- `github_repository`: your fork in `owner/repository` form, such as `Taihoclaptrinh/microservices-repo`;
- `cluster_endpoint_public_access_cidrs`: your own public IPv4 address followed by `/32`, such as `203.0.113.10/32` (replace the documentation address with your real address).

Do not use `0.0.0.0/0` for the Kubernetes API. If your public IP changes, update the variable and apply a reviewed plan before using `kubectl` again.

### Read the configuration before applying

Read `versions.tf`, `variables.tf`, and `main.tf` in that order. Identify:

- the VPC's public and private subnet ranges and single NAT gateway;
- the EKS control-plane endpoint settings and managed node group;
- the ECR repository names and image cleanup policy;
- the GitHub OIDC provider and the exact repository/branch trust condition;
- the resources that remain after an EKS destroy, especially the separate S3 state bucket.

Initialize and validate without applying:

```bash
terraform init -backend-config=backend.hcl
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
```

Read the entire plan. `plan` is a preview, but it can call AWS APIs and requires valid credentials. It does not create the planned resources. Check the region, cluster name/version, public API CIDR, subnet ranges, IAM policy scope, and expected resource count. If any value is unexpected, stop and correct the inputs.

Only when you are ready to pay for the environment, apply the saved plan:

```bash
terraform apply tfplan
rm tfplan
```

The saved plan can contain sensitive values. Do not commit it; remove it after applying. Record the outputs:

```bash
terraform output
terraform output -raw github_actions_role_arn
terraform output -raw cluster_name
terraform output -raw cluster_region
```

This creates the VPC, NAT gateway, EKS control plane and worker nodes, ECR repositories, and GitHub publishing role. EKS and NAT gateway charges continue while they exist, even when the application is idle.

**Checkpoint before apply:** you can explain every resource in the plan, have confirmed your AWS identity and region, set the API CIDR to your own IP, and know how you will destroy the stack.

## 6. Fourth lab: GitHub Actions and ECR

The workflow has three jobs/paths:

1. Pull requests build the eleven images without AWS credentials.
2. Pushes to `practice/devops-from-scratch` use GitHub OIDC to assume the Terraform-created role and push images tagged with the commit SHA.
3. After all image pushes succeed, Actions opens a pull request changing `global.imageTag` in the Helm values. Merging that PR is the deployment promotion.

After Terraform succeeds, in your fork's **Settings → Secrets and variables → Actions → Variables**, add:

| Variable | Value |
|---|---|
| `AWS_ECR_ROLE_ARN` | Terraform output `github_actions_role_arn` |
| `AWS_REGION` | Terraform input `aws_region` |

These are repository variables, not AWS access keys. Do not add `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY`; the workflow uses the OIDC role.

The workflow only publishes on a push to the configured practice branch. A pull request can run the no-credential build check from an exercise branch. If you change the publishing branch, change both the workflow branch trigger and Terraform's `github_ref` so they continue to match exactly.

Because the workflow only runs on a future qualifying push, adding variables does not rerun an old workflow. After setting the variables, make and push a real service-source or Dockerfile change to the practice branch when you are ready to publish. Confirm the GitHub Actions run succeeds and the ECR repositories contain tags matching the commit SHA. Then review the generated promotion PR before merging it.

**Checkpoint:** the PR build needs no AWS secrets; the branch build assumes the narrowly scoped role; each ECR tag is immutable; and a promotion PR changes the chart tag rather than deploying directly from CI.

## 7. Fifth lab: connect kubectl and deploy with Argo CD

After Terraform apply, configure `kubectl` using the actual outputs:

```bash
aws eks update-kubeconfig \
  --region "$(terraform -chdir=infra/terraform output -raw cluster_region)" \
  --name "$(terraform -chdir=infra/terraform output -raw cluster_name)"

kubectl get nodes
kubectl get namespaces
```

The EKS nodes are private. The Kubernetes API has both private and CIDR-restricted public access so your machine can connect from the CIDR you configured.

Before Argo CD syncs the application:

1. Set `global.awsAccountId` and `global.awsRegion` in `deploy/helm/online-boutique/values.yaml` for the chart in Git.
2. Replace `<owner>` in `deploy/argocd/online-boutique.yaml` with your GitHub account or organization.
3. Ensure the chart's `global.imageTag` has been updated to an image SHA that exists in ECR. The promotion PR is the normal way to do this.
4. Install Argo CD using the official installation instructions, choosing and pinning a release. If the fork is private, configure repository access in Argo CD; do not put a token in the Application manifest.
5. Apply the Application:

```bash
kubectl apply -f deploy/argocd/online-boutique.yaml
```

Watch reconciliation:

```bash
kubectl get applications -n argocd
kubectl get pods -n online-boutique --watch
kubectl get services -n online-boutique
```

When the frontend Service receives an external address, open it in a browser. It may take a few minutes for AWS to create the load balancer. Backend services and Redis remain internal. Verify the store loads and try a cart/checkout flow; check the pod logs if a service is unhealthy:

```bash
kubectl logs -n online-boutique deployment/frontend
kubectl describe pod -n online-boutique <pod-name>
kubectl get events -n online-boutique --sort-by=.lastTimestamp
```

**Checkpoint:** Argo CD reports the app synced and healthy; all expected pods are ready; the frontend is reachable; and you can follow a failing request from frontend logs to the downstream service.

## 8. Troubleshooting guide

| Symptom | First checks |
|---|---|
| Terraform says the GitHub OIDC provider already exists | OIDC providers are account-wide. Do not create a duplicate; inspect the existing provider and import it into this state only after confirming it is the correct GitHub provider. |
| Terraform cannot find two availability zones | Choose a region with at least two available zones and check account/region restrictions. |
| `kubectl` times out after apply | Confirm the current public IP matches the configured `/32`, AWS CLI identity is the Terraform cluster creator, and kubeconfig points to the right region/cluster. |
| GitHub reports `Not authorized to perform sts:AssumeRoleWithWebIdentity` | Compare `github_repository`, `github_ref`, workflow branch, and fork owner/name character-for-character. Check that the repository variables are set. |
| ECR push is denied | Check the OIDC role output, AWS region variable, workflow run branch, ECR repository names, and IAM policy scope. |
| Pod is `ImagePullBackOff` | Compare chart account/region/tag with ECR. Confirm the matching SHA exists and the EKS node role can pull ECR images. |
| Pod is `Pending` | Use `kubectl describe pod`; check node readiness, available CPU/memory, and events. |
| Frontend Service has no external address | Inspect Service events, subnet role tags, and AWS load-balancer events. Confirm the public subnets are associated with the VPC and tagged for external load balancers. |
| Argo CD cannot load the chart | Check repository URL, target revision, path, and whether Argo CD has access to a private fork. |

## 9. Cleanup and cost control

Delete the Argo CD Application, explicitly remove its namespace so Kubernetes cleans up Services and the frontend load balancer, wait for deletion, then destroy Terraform resources:

```bash
kubectl delete -f deploy/argocd/online-boutique.yaml
kubectl delete namespace online-boutique --wait=true
kubectl get services -A
terraform -chdir=infra/terraform destroy
```

Review the destroy plan before confirming it. Afterward, verify in AWS that the EKS cluster, EC2 nodes, NAT gateway, ECR repositories, and load balancer are gone. The ECR repositories are configured for this disposable exercise and are allowed to be force-deleted with their images. Keep the Terraform S3 state bucket until you no longer need the state/history; delete it separately only after confirming it contains nothing you need.

Do not leave the environment running between study sessions. Current regional prices vary, so check AWS pricing before applying rather than relying on a fixed estimate.

## 10. What this starter does not provide

This is a learning baseline, not a production platform:

- Redis is a single pod without persistent storage or replication; cart contents are disposable.
- The chart uses simple TCP probes and baseline resource requests/limits; it does not autoscale services.
- The frontend gets a basic AWS load balancer, without a custom domain, HTTPS, or WAF.
- Argo CD installation and AWS Load Balancer Controller are not provisioned by Terraform.
- Monitoring, alerting, network policies, Pod Security settings, backups, and disaster recovery are not configured.
- The GitHub OIDC provider is account-wide. If it already exists, resolve that state intentionally before applying.
- The ECR cleanup policy and `force_delete` behavior are for practice only; review them before adapting this configuration for a persistent environment.
