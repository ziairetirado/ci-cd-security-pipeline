variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Name of the demo S3 bucket"
  type        = string
  default     = "cicd-security-demo-bucket"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "demo"
}
