output "bucket_name" {
  description = "Name of the demo S3 bucket"
  value       = aws_s3_bucket.demo.id
}

output "security_group_id" {
  description = "ID of the demo security group"
  value       = aws_security_group.demo.id
}
