# ---------------------------------------------------- #
# terraform/variables.tf
# ---------------------------------------------------- #

# This file defines input variables for Terraform
# Makes the infrastructure configurable without editing main.tf

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "MLOps Final Project>"
  type        = string
  default     = "MLOps"
}

variable "github_token" {
  description = "GitHub personal access token for CodePipeline"
  type        = string
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub username or organization"
  type        = string
  default     = "jakobflechsenhar"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "mlops"
}