# -----------------------------------------------------------------------
# Demo infrastructure for the CI/CD security pipeline.
#
# NOTE: This config is intentionally left with a few common
# misconfigurations (public S3 bucket, no encryption, SSH open to the
# world) so the pipeline has something real to catch. See README.md
# "What the pipeline catches" for the fixed versions of each resource.
# -----------------------------------------------------------------------

resource "aws_s3_bucket" "demo" {
  bucket = var.bucket_name

  tags = {
    Environment = var.environment
    Project     = "cicd-security-pipeline"
  }
}

# Intentional finding: bucket ACL allows public read
resource "aws_s3_bucket_acl" "demo" {
  bucket = aws_s3_bucket.demo.id
  acl    = "public-read"
}

# Intentional finding: no server-side encryption configured
# (tfsec/checkov flag missing aws_s3_bucket_server_side_encryption_configuration)

# Intentional finding: no versioning configured
# (checkov flags missing aws_s3_bucket_versioning)

resource "aws_security_group" "demo" {
  name        = "cicd-security-demo-sg"
  description = "Demo security group with an overly permissive rule"

  # Intentional finding: SSH open to the entire internet
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
    Project     = "cicd-security-pipeline"
  }
}
