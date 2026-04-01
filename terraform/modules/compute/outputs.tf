output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.dns_name
}

output "s3_bucket_name" {
  description = "S3 bucket name for website files"
  value       = aws_s3_bucket.website.bucket
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.app.name
}
