# ---------------------------------------------------- #
# terraform/outputs.tf
# ---------------------------------------------------- #

# This file defines what information to show after Terraform runs
# These outputs help you know what was created and how to access it

output "lambda_function_url" {
  description = "URL of the Lambda function"
  value       = aws_lambda_function_url.model_api_url.function_url
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"  # Where Docker images are stored
  value       = aws_ecr_repository.mlops_repo.repository_url
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"  # Where models are stored
  value       = aws_s3_bucket.mlops_bucket.id
}

output "total_monthly_cost_estimate" {
  description = "Rough estimate of monthly costs"
  value       = "~$5-10 if left running (Lambda + S3 + ECR)"  # Static string for reference
}

output "codepipeline_name" {
  description = "Name of the CodePipeline"
  value       = aws_codepipeline.mlops_pipeline.name
}