output "website_url" {
  description = "Portfolio website URL (ALB DNS)"
  value       = "http://${module.compute.alb_dns_name}"
}

output "s3_bucket_name" {
  description = "S3 bucket storing website files"
  value       = module.compute.s3_bucket_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = module.compute.asg_name
}
