# ---------------------------------------------------- #
# terraform/main.tf
# ---------------------------------------------------- #

# This file defines all AWS infrastructure as code
# When you run 'terraform apply', it creates all these resources in AWS


# ---------------------------------------------------- #
# ===== TERRAFORM CONFIGURATION =====
# ---------------------------------------------------- #

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"      # Official AWS provider from HashiCorp
      version = "~> 5.0"             # Use version 5.x (won't auto-upgrade to 6.x)
    }
  }
  required_version = ">= 1.0"        # Minimum Terraform version required
}
# ---------------------------------------------------- #


# ---------------------------------------------------- #
# ===== AWS PROVIDER CONFIGURATION =====
# ---------------------------------------------------- #

provider "aws" {
  region = var.aws_region            # Which AWS region to create resources in (us-east-1)
}
# ---------------------------------------------------- #


# ---------------------------------------------------- #
# ===== RANDOM SUFFIX FOR UNIQUE NAMING =====
# ---------------------------------------------------- #

# AWS requires globally unique names for S3 buckets and other resources
resource "random_string" "suffix" {
  length  = 8                        # 8 random characters (e.g., "a3b2c1d4")
  special = false                    # No special characters like !@#$
  upper   = false                    # Lowercase only (AWS prefers lowercase)
}
# ---------------------------------------------------- #


# ---------------------------------------------------- #
# ===== STORAGE RESOURCES =====
# ---------------------------------------------------- #

# S3 Bucket - Where we store the trained model files
resource "aws_s3_bucket" "mlops_bucket" {
  bucket = "mlops-${random_string.suffix.result}"  # e.g., "mlops-a3b2c1d4"
}

# S3 Bucket Security - Ensure the bucket is completely private
resource "aws_s3_bucket_public_access_block" "mlops_bucket" {
  bucket = aws_s3_bucket.mlops_bucket.id           # Apply to bucket above

  block_public_acls       = true     # Prevent public ACLs from being set
  block_public_policy     = true     # Prevent public bucket policies
  ignore_public_acls      = true     # Ignore any existing public ACLs
  restrict_public_buckets = true     # Ensure bucket can't be made public
}

# ECR Repository - Where we store Docker container images
resource "aws_ecr_repository" "mlops_repo" {
  name = "mlops-${random_string.suffix.result}"     # e.g., "mlops-a3b2c1d4"
  
  image_tag_mutability = "MUTABLE"   # Allow overwriting tags like "latest"
  
  image_scanning_configuration {
    scan_on_push = false             # Don't scan for vulnerabilities (costs extra)
  }
}
# ---------------------------------------------------- #


# ---------------------------------------------------- #
# ===== IAM ROLES AND POLICIES =====
# ---------------------------------------------------- #

# IAM controls who/what can access AWS resources
# IAM Role for Lambda - Defines what Lambda is allowed to assume
resource "aws_iam_role" "lambda_role" {
  name = "mlops-lambda-role-${random_string.suffix.result}"
  
  # Trust policy - Says "Lambda service can use this role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"    # Allow assuming the role
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"  # Only Lambda service can use this
        }
      }
    ]
  })
}

# IAM Policy for Lambda - Defines what Lambda can actually do
resource "aws_iam_role_policy" "lambda_policy" {
  name = "mlops-lambda-policy"
  role = aws_iam_role.lambda_role.id # Attach to the role above

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Allow Lambda to write logs to CloudWatch
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",     # Create new log groups
          "logs:CreateLogStream",    # Create streams within groups
          "logs:PutLogEvents"        # Actually write log messages
        ]
        Resource = "arn:aws:logs:*:*:*"  # Any log group/stream
      },
      {
        # Allow Lambda to read the model from S3
        Effect = "Allow"
        Action = [
          "s3:GetObject",            # Read/download files
          "s3:ListBucket"            # List bucket contents
        ]
        Resource = [
          aws_s3_bucket.mlops_bucket.arn,           # The bucket itself
          "${aws_s3_bucket.mlops_bucket.arn}/*"     # All files in bucket
        ]
      }
    ]
  })
}
# ---------------------------------------------------- #


# ---------------------------------------------------- #
# ===== COMPUTE RESOURCES =====
# ---------------------------------------------------- #

# Lambda Function - The serverless API that serves predictions
resource "aws_lambda_function" "model_api" {
  function_name = "mlops-model-api-${random_string.suffix.result}"
  role          = aws_iam_role.lambda_role.arn  # Use the IAM role above
  
  package_type = "Image"                        # Using Docker container (not ZIP)
  image_uri    = "${aws_ecr_repository.mlops_repo.repository_url}:latest"
  
  timeout     = 30         # Kill function if it runs >30 seconds
  memory_size = 128        # Minimum RAM (128MB) to minimize cost
  
  # Environment variables passed to the Lambda function
  environment {
    variables = {
      MODEL_BUCKET = aws_s3_bucket.mlops_bucket.id    # Tell Lambda which bucket
      MODEL_KEY    = "models/model.pkl"               # Tell Lambda which file
    }
  }
  
  # Make sure IAM policy exists before creating Lambda
  depends_on = [
    aws_iam_role_policy.lambda_policy
  ]
}

# Lambda Function URL - Creates a public HTTPS endpoint for the Lambda
# This is like a simple API Gateway but free!
resource "aws_lambda_function_url" "model_api_url" {
  function_name      = aws_lambda_function.model_api.function_name
  authorization_type = "NONE"    # No authentication required (for testing)
}
# ---------------------------------------------------- #


# ---------------------------------------------------- #
# ===== MONITORING =====
# ---------------------------------------------------- #

# CloudWatch Log Group - Where Lambda function logs are stored
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.model_api.function_name}"
  retention_in_days = 1          # Delete logs after 1 day (save money)
}
# ---------------------------------------------------- #


# ---------------------------------------------------- #
# ===== CI/CD RESOURCES =====
# ---------------------------------------------------- #

# CodeBuild Project - Builds Docker images and trains models
resource "aws_codebuild_project" "mlops_build" {
  name = "mlops-build-${random_string.suffix.result}"
  
  service_role = aws_iam_role.codebuild_role.arn  # IAM role for permissions
  
  artifacts {
    type = "CODEPIPELINE"        # Will be triggered by CodePipeline (future)
  }
  
  # Build environment configuration
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"     # Smallest/cheapest
    image                      = "aws/codebuild/standard:5.0" # AWS Linux image
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode            = true                        # Needed for Docker
    
    # Environment variables available during build
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
    
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id    # Your AWS account
    }
    
    environment_variable {
      name  = "ECR_REPO_URL"
      value = aws_ecr_repository.mlops_repo.repository_url   # Where to push
    }
    
    environment_variable {
      name  = "S3_BUCKET"
      value = aws_s3_bucket.mlops_bucket.id                  # Where to save model
    }
  }
  
  # Where to find build instructions
  source {
    type = "CODEPIPELINE"
    buildspec = "scripts/buildspec.yml"   # File with build commands
  }
}

# IAM Role for CodeBuild - What CodeBuild is allowed to assume
resource "aws_iam_role" "codebuild_role" {
  name = "mlops-codebuild-role-${random_string.suffix.result}"

  # Trust policy - Says "CodeBuild service can use this role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"   # Only CodeBuild can use this
        }
      }
    ]
  })
}

# IAM Policy for CodeBuild - What CodeBuild can actually DO
resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # CloudWatch Logs permissions
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          
          # ECR (Docker registry) permissions
          "ecr:GetAuthorizationToken",         # Login to ECR
          "ecr:BatchCheckLayerAvailability",   # Check if layers exist
          "ecr:GetDownloadUrlForLayer",        # Download layers
          "ecr:BatchGetImage",                 # Pull images
          "ecr:PutImage",                      # Push images
          "ecr:InitiateLayerUpload",          # Start upload
          "ecr:UploadLayerPart",              # Upload chunks
          "ecr:CompleteLayerUpload",          # Finish upload
          
          # S3 permissions
          "s3:GetObject",                      # Read from S3
          "s3:PutObject",                      # Write to S3
          "s3:GetBucketLocation"               # Get bucket metadata
        ]
        Resource = "*"                         # Access all resources (simplified)
      }
    ]
  })
}
# ---------------------------------------------------- #


# ---------------------------------------------------- #
# ===== DATA SOURCES =====

# Get current AWS account ID dynamically
data "aws_caller_identity" "current" {}  # Provides account_id, arn, user_id
# ---------------------------------------------------- #


# ---------------------------------------------------- #
# ===== CODEPIPELINE FOR FULL CI/CD =====

# S3 Bucket for CodePipeline artifacts
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = "mlops-pipeline-artifacts-${random_string.suffix.result}"
}

resource "aws_s3_bucket_public_access_block" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CodePipeline
resource "aws_codepipeline" "mlops_pipeline" {
  name     = "mlops-pipeline-${random_string.suffix.result}"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        Owner      = var.github_owner
        Repo       = var.github_repo
        Branch     = "main"
        OAuthToken = var.github_token
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.mlops_build.name
      }
    }
  }
}

# IAM Role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "mlops-codepipeline-role-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.pipeline_artifacts.arn,
          "${aws_s3_bucket.pipeline_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = aws_codebuild_project.mlops_build.arn
      }
    ]
  })
}
# ---------------------------------------------------- #