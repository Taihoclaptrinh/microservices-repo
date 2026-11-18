# Online Boutique on AWS EKS

A hands-on DevOps practice repo for the Online Boutique microservices demo. It adapts the delivery concepts from `springboot-eks-devops` to this app's eleven core services, gRPC calls, and Redis cart store.

## Start here

1. Read the [learning roadmap](docs/devops-learning-roadmap.md) to follow the labs in order.
2. Use the [AWS EKS delivery guide](docs/devops-implementation.md) for the repository map, exact commands, verification steps, troubleshooting, and cleanup.
3. Keep `practice/devops-from-scratch` as your reference. Rebuild or improve one area at a time in a short-lived exercise branch.

The repo includes Dockerfiles, a Helm chart, Terraform, GitHub Actions, and an Argo CD Application. This is a learning baseline: Redis is ephemeral, observability and TLS are follow-on labs, and applying Terraform creates billable AWS resources. The optional Google Cloud shopping assistant and RDS are not part of this deployment.
