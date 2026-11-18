# AWS EKS delivery guide

This branch now contains a starter implementation of the delivery flow adapted from `springboot-eks-devops`. It targets Online Boutique's core services and Redis. It does not create RDS, use Google Cloud deployment services, or enable the optional shopping assistant.

## Flow and repository map

```text
src/* Dockerfiles -> GitHub Actions -> immutable ECR images
Terraform -> VPC + EKS + ECR + GitHub OIDC role
Helm chart -> core services + Redis -> Argo CD on EKS
```

- `src/*/Dockerfile`: service image builds restored from the upstream application repo.
- `infra/terraform/`: VPC, private EKS worker nodes, ECR repositories, and a branch-scoped GitHub OIDC publishing role.
- `deploy/helm/online-boutique/`: Kubernetes Deployments and Services, plus Redis.
- `deploy/argocd/online-boutique.yaml`: Argo CD Application starter.
- `.github/workflows/`: PR image-build checks, ECR publishing, image-promotion PR, and Terraform validation.

## Before Terraform

1. Install AWS CLI, Terraform 1.10+, kubectl, Helm, and Argo CD CLI. Configure a named AWS profile with enough permissions to create the practice stack.
2. Create a dedicated S3 bucket for Terraform state with versioning and encryption. Do not reuse a public bucket. Copy `infra/terraform/backend.hcl.example` to `backend.hcl` and fill the bucket and region.
3. Copy `terraform.tfvars.example` to `terraform.tfvars`; confirm the EKS version is supported in your region, set your repository, and enter your own public IPv4 address in `/32` form. The example version is a snapshot; AWS changes supported versions over time.
4. Initialize, inspect the plan, then apply:

```sh
cd infra/terraform
terraform init -backend-config=backend.hcl
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

5. Save the `github_actions_role_arn` output as the repository variable `AWS_ECR_ROLE_ARN` and `aws_region` as `AWS_REGION`. The trust policy only permits the configured repository and branch to assume this ECR publishing role.
6. Configure kubectl:

```sh
aws eks update-kubeconfig --region <AWS_REGION> --name <CLUSTER_NAME>
```

The API endpoint is public but limited to the CIDRs you configure; worker nodes run in private subnets. One NAT gateway and two `t3.medium` workers incur ongoing costs. Destroy the practice stack when finished.

## Images and promotion

Pull requests build all 11 core service images without AWS credentials. A push to `practice/devops-from-scratch` uses GitHub OIDC to push commit-SHA tags to ECR. Then Actions opens a PR updating the chart's `global.imageTag`; review and merge it to promote that release. No long-lived AWS access keys are needed.

## Argo CD and Helm

Install Argo CD into the cluster, edit the GitHub owner in `deploy/argocd/online-boutique.yaml` and set the AWS account ID and region in `deploy/helm/online-boutique/values.yaml`, then apply the Application. The chart exposes only the frontend through an AWS load balancer; the gRPC services and Redis stay ClusterIP-only. Confirm the load balancer health and app flow before adding DNS/TLS.

## Important limits and next exercises

- Redis is a single in-cluster pod with no durable storage: suitable for a demo, not production.
- The current chart uses TCP probes and modest resource requests; tune after measuring the workload.
- Terraform creates ECR repositories and an image-push role, but cluster authentication for your human AWS identity depends on the Terraform applying identity and your AWS account's EKS access setup.
- Argo CD installation, AWS Load Balancer Controller, DNS/TLS, monitoring, network policies, and production hardening are follow-on exercises. The prior repo's EFK stack is not copied because its Elasticsearch footprint is costly for a small practice cluster.
- The GitHub OIDC provider is account-wide. If your AWS account already has one, import the existing provider into Terraform state before applying.
- Terraform's `force_delete` on ECR is intended for this disposable practice environment; remove it before using this as a production baseline.
