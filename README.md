# Online Boutique on AWS EKS

A practice deployment of the Online Boutique microservices demo using the delivery ideas from `springboot-eks-devops`: Docker, GitHub Actions, Amazon ECR, Terraform, EKS, Helm, and Argo CD.

The app has eleven core services in several languages and uses Redis for the cart. This stack does not deploy the optional Google Cloud shopping assistant, GCP services, or RDS.

## What's included

- Restored upstream Dockerfiles for the eleven core services under `src/`.
- Terraform for a VPC, private EKS worker nodes, ECR repositories, and branch-scoped GitHub OIDC publishing role in `infra/terraform/`.
- Helm chart for the services and demo Redis in `deploy/helm/online-boutique/`.
- GitHub Actions for pull-request image builds, OIDC-authenticated ECR publishing, an image-promotion PR, and Terraform validation.
- Argo CD Application starter in `deploy/argocd/`.
- Step-by-step setup, costs, limitations, and follow-on exercises in [`docs/devops-implementation.md`](docs/devops-implementation.md) and [`docs/devops-learning-roadmap.md`](docs/devops-learning-roadmap.md).

## Start here

Read the [AWS EKS delivery guide](docs/devops-implementation.md) before applying Terraform. The example requires your own AWS account, a versioned S3 state bucket, repository variables, your public IP CIDR, and a review of the Terraform plan. It creates billable AWS resources; destroy the stack when you finish practicing.

This is a learning baseline, not a production-ready platform. Redis is ephemeral, and DNS/TLS, monitoring, and production hardening are follow-on exercises.
