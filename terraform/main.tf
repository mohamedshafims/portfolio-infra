# Networking layer — VPC, subnets, security groups
module "networking" {
  source = "./modules/networking"

  environment         = var.environment
  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
}

# Compute layer — S3, ALB, Launch Template, ASG
module "compute" {
  source = "./modules/compute"

  environment           = var.environment
  project_name          = var.project_name
  vpc_id                = module.networking.vpc_id
  public_subnets        = module.networking.public_subnets
  alb_security_group_id = module.networking.alb_security_group_id
  ec2_security_group_id = module.networking.ec2_security_group_id
}
