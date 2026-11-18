variable "aws_region" {
  description = "AWS region for this practice environment"
  type        = string
}

variable "cluster_name" {
  description = "Unique EKS cluster name"
  type        = string
  default     = "online-boutique-practice"
}

variable "cluster_version" {
  description = "EKS Kubernetes version supported in aws_region"
  type        = string
}

variable "github_repository" {
  description = "GitHub owner/repository allowed to publish images"
  type        = string
}

variable "github_ref" {
  description = "Exact Git ref allowed to publish images"
  type        = string
  default     = "refs/heads/practice/devops-from-scratch"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "Public IPv4 CIDRs allowed to reach the Kubernetes API"
  type        = list(string)
  validation {
    condition     = length(var.cluster_endpoint_public_access_cidrs) > 0
    error_message = "Set at least your own public IPv4 CIDR; do not open the API to everyone."
  }
}
