# DevOps learning roadmap

Use this branch as a reference implementation, not as a finished assignment. For each milestone, read the starter, write down what you think it does, then recreate or improve it in a short-lived exercise branch. Compare your result with `practice/devops-from-scratch` before merging.

The application has eleven core services in several languages, uses gRPC between services, and stores cart state in Redis. The AWS exercise deliberately skips the optional Google Cloud shopping assistant and does not create MySQL/RDS.

## A repeatable practice loop

For each milestone:

1. **Read:** identify the relevant files and trace one request or resource from input to outcome.
2. **Predict:** write down what command or change should happen and what success should look like.
3. **Build:** create an exercise branch from `practice/devops-from-scratch` and make the smallest working version.
4. **Check:** use the milestone's checks; save command output or a short note as evidence.
5. **Compare:** inspect the diff against the reference branch. Explain every meaningful difference.
6. **Finish:** merge only when you understand the result. Keep AWS resources destroyed unless that milestone explicitly needs them.

Example branch names:

```text
learn/01-container-productcatalog
learn/02-helm-chart
learn/03-terraform-vpc-eks
learn/04-github-actions-ecr
learn/05-argocd-gitops
```

Do not try to implement every platform feature in one branch. Each lab should have one goal, a small diff, and a clear completion check.

## Milestone 0 — map the application

**Goal:** understand what the platform must run before changing infrastructure.

1. Read the root README and architecture diagram.
2. Pick the checkout flow. Trace frontend → checkout → cart, currency, payment, shipping, product catalog, and email.
3. Identify which services use HTTP, which use gRPC, and which service depends on Redis.
4. Use the service and port table in [the implementation guide](devops-implementation.md) as a starting point; verify details against the app source and manifest values.
5. Draw a small diagram and label the network destination each caller uses.

**Evidence:** a one-page service map with service name, language, listen port, callers, and dependency addresses.

**Done when:** you can explain why running the frontend container alone does not make the store work.

## Milestone 1 — Docker images

**Goal:** understand the image build context and produce reproducible images.

1. Start with `src/productcatalogservice/Dockerfile` and its Go module.
2. Build the image using the exact context command in the implementation guide.
3. Inspect the layers and image metadata with `docker history` and `docker image inspect`.
4. Run the service container with its `PORT` set and observe logs. Stop it; do not treat a running gRPC process as a full application test.
5. Repeat for the other ten services. Pay special attention to cart's nested Docker context and to the different language toolchains.
6. Read each `.dockerignore`. Propose one safe improvement and explain what build input it excludes.
7. After manual builds work, write a small script or Makefile target to avoid repeating commands. Keep the manual command understandable too.

**Evidence:** successful build output for all core services, image names/tags, and a note describing each service's build stage and runtime entrypoint.

**Done when:** a clean checkout can build all eleven images from the documented contexts without using a remote prebuilt image.

## Milestone 2 — Kubernetes objects and Helm

**Goal:** understand the resources before applying them to a cluster.

1. Read `deploy/helm/online-boutique/values.yaml` and map service ports and environment variables to Milestone 0.
2. Read `templates/services.yaml`. Trace how the `services` values generate Deployments and Services.
3. Read `templates/redis.yaml`. Explain the cart-to-Redis DNS name and why this Redis is disposable.
4. Run `helm lint` and `helm template` as shown in the implementation guide.
5. Inspect the rendered YAML. Find labels/selectors, ports, images, probes, and resource requests.
6. In an exercise branch, change one harmless value, render again, and compare the output. Then add one missing improvement, such as a namespace-scoped NetworkPolicy or a Pod security context.
7. Only later, apply to a local Kubernetes cluster or EKS. Check `kubectl get`, `describe`, `logs`, and events.

**Evidence:** rendered manifests and a short explanation of how a frontend request resolves each Kubernetes Service DNS name.

**Done when:** you can predict what Helm will render and diagnose a selector or port mismatch from the output.

## Milestone 3 — Terraform and AWS foundations

**Goal:** understand infrastructure state, networking, IAM, and cost before creating a cluster.

1. Read `infra/terraform/versions.tf`, `variables.tf`, `main.tf`, and `outputs.tf` in order.
2. Draw the public/private subnet route: public load balancer → frontend; private worker nodes → NAT for outbound traffic; EKS API reachable privately from nodes and publicly only from your configured CIDR.
3. Explain the VPC module, EKS module, node group, ECR repositories, OIDC provider, and GitHub role policy.
4. Create a dedicated encrypted, versioned S3 bucket for Terraform state. Understand why state is sensitive and why the bucket is not part of this stack's destroy.
5. Copy the example variable/backend files, use your own fork/repository and public IP, and select a region and EKS version supported for that region.
6. Run `terraform init`, `fmt`, `validate`, and `plan`. Read every planned resource before applying.
7. Apply only when ready to incur ongoing AWS cost. Record outputs, connect `kubectl`, inspect nodes, then destroy the resources when the lab is over.
8. After the first successful run, practice a change in a disposable environment: add an output, inspect a plan, apply, and remove it. Never hand-edit state.

**Evidence:** a VPC/EKS sketch, saved plan review notes, `terraform output`, `kubectl get nodes`, and a verified destroy.

**Done when:** you can explain which Terraform resources are billable and identify what the state backend retains.

## Milestone 4 — GitHub Actions and image publishing

**Goal:** separate untrusted pull-request builds from authenticated image publishing.

1. Read `.github/workflows/app.yml` top to bottom. Mark each event, permission, job condition, matrix value, AWS credential step, and image tag.
2. Open a pull request from an exercise branch. Confirm the build job works without AWS credentials.
3. After Terraform, add only `AWS_ECR_ROLE_ARN` and `AWS_REGION` as GitHub repository variables.
4. Understand how the AWS OIDC role trust binds the owner/repository and branch. Confirm it does not grant Kubernetes admin access.
5. Make a source or Dockerfile change on the configured publishing branch. Confirm the workflow publishes SHA-tagged images.
6. Review the generated promotion PR. Verify that it changes the Helm image tag and that the images exist before merging.
7. Improve the pipeline later: unit tests, dependency/image scanning, SBOM, caching, and build-only-changed-services logic.

**Evidence:** one successful no-credential PR build, one successful OIDC push, and one reviewed image-promotion PR.

**Done when:** the pipeline uses no long-lived AWS access keys and CI does not directly run `kubectl apply`.

## Milestone 5 — EKS deployment and GitOps

**Goal:** let Git describe the accepted release and Argo CD reconcile it.

1. Install Argo CD into the EKS cluster using a pinned release.
2. Set the chart's AWS account ID/region and the Argo Application's fork URL/branch.
3. Ensure a promoted image SHA exists in ECR before the Application syncs.
4. Apply the Argo CD Application and watch its sync/health status.
5. Check pod readiness, frontend load balancer, and a user flow through the store.
6. Make another source change, merge its promotion PR, and watch Argo CD deploy it.
7. Roll back by reverting the Git promotion commit. Do not use an untracked live-cluster edit as the release record.

**Evidence:** Argo Application status, ready pod list, reachable frontend, and successful rollback.

**Done when:** a reviewed Git change deploys and reverts the release without CI holding broad Kubernetes credentials.

## Milestone 6 — operations and production thinking

Do these after the basic flow works:

- Add CloudWatch Container Insights or a Prometheus-based stack, then create one useful dashboard and alert.
- Add network policies that permit only required service-to-service calls; test that the checkout flow still works.
- Add the AWS Load Balancer Controller with a dedicated IAM role, a Route 53 name, and HTTPS. Expose only the frontend.
- Replace demo Redis with a durable, backed-up cart store and document recovery behavior.
- Add autoscaling only after you have resource metrics and a load profile.
- Review image provenance, dependency findings, secret handling, IAM scope, and cluster access.
- Write a short failure runbook for `ImagePullBackOff`, pending pods, failed probes, and unavailable downstream services.

**Evidence:** dashboard, alert test, restricted network flow, restore/recovery notes, and a cost-aware teardown checklist.

## Stop/go gates

| Gate | Continue when | Stop if |
|---|---|---|
| Before Docker work | Docker is installed and you know which build context you are using | Build context or image entrypoint is unclear |
| Before Terraform apply | AWS identity, region, version, API CIDR, state bucket, plan, and cleanup plan are reviewed | Plan exposes the API broadly, uses the wrong account, or includes unexplained resources |
| Before image publishing | OIDC role trust matches your fork and exact branch; repository variables are set | Workflow would need a long-lived AWS key or broad admin permissions |
| Before Argo sync | Chart account/region and a real image SHA in ECR are set | Chart still points to placeholder account/tag values |
| Before ending a cloud lab | Terraform destroy completed and AWS resource check is clean | NAT gateway, cluster, load balancer, or EC2 node remains unexpectedly |

For exact commands and the current starter's limitations, use the [AWS EKS delivery guide](devops-implementation.md).
