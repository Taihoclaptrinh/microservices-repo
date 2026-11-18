output "cluster_name" { value = module.eks.cluster_name }
output "cluster_region" { value = var.aws_region }
output "ecr_registry" { value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com" }
output "github_actions_role_arn" { value = aws_iam_role.github_ecr.arn }
output "ecr_repositories" { value = { for name, repo in aws_ecr_repository.service : name => repo.repository_url } }
