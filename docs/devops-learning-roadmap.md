# DevOps learning roadmap

This branch now includes a working-shape starter for the AWS EKS delivery flow. Use it as a study/reference implementation, then improve it in small milestones. The core app has eleven services, uses gRPC between services, and stores cart state in Redis; it does not need the Spring Boot example's MySQL/RDS layer.

## Current implementation

- Container build definitions are in each core service's `src/*/Dockerfile`.
- `infra/terraform/` provisions a VPC, EKS managed nodes, ECR, and a GitHub OIDC role scoped to this repository and practice branch.
- `deploy/helm/online-boutique/` deploys the services plus a demo Redis instance.
- `.github/workflows/` builds on pull requests, publishes immutable SHA-tagged images on the practice branch, and opens a promotion PR for Argo CD.
- `deploy/argocd/` contains the GitOps Application starter.
- Detailed setup and limits: [AWS EKS delivery guide](devops-implementation.md).

## Practice milestones

1. **Containers:** build and run one service locally; inspect its image layers and test its gRPC dependency assumptions. Repeat for the remaining services.
2. **Kubernetes:** render the Helm chart and trace Deployments, Services, probes, resource requests, and service discovery. Add namespace quotas and network policies.
3. **Terraform:** read every module input and output, create versioned encrypted S3 state, inspect the plan, then create and destroy the AWS environment. Practice state locking and drift review.
4. **CI:** add unit tests and language-specific checks before builds. Improve the matrix so only changed services build. Keep PRs free of AWS credentials.
5. **Image supply chain:** add SBOM generation and image scanning. Decide how you will review and respond to findings.
6. **GitOps:** merge an image-promotion PR, watch Argo CD reconcile it, and roll back by reverting the Git change.
7. **Operations:** add CloudWatch Container Insights or a Prometheus stack, alerts, dashboards, and a failure runbook.
8. **Ingress and TLS:** install AWS Load Balancer Controller with a dedicated IAM role, expose only the frontend, then add Route 53 and ACM or cert-manager.
9. **Production design:** replace ephemeral Redis, set availability and backup goals, tune scaling and budgets, and document recovery and teardown.

The Terraform example creates billable EKS, NAT, and EC2 resources. Check current regional pricing and EKS version support before applying, and run `terraform destroy` when you are done.
