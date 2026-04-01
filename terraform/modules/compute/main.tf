# ─────────────────────────────────────────────
# S3 Bucket — stores website files (HTML, CSS)
# ─────────────────────────────────────────────
resource "aws_s3_bucket" "website" {
  bucket_prefix = "${var.project_name}-site-"

  tags = {
    Name = "${var.project_name}-website"
  }
}

# ─────────────────────────────────────────────
# IAM — EC2 role to read website files from S3
# ─────────────────────────────────────────────
resource "aws_iam_role" "ec2" {
  name_prefix = "${var.project_name}-ec2-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "s3_read" {
  name_prefix = "s3-read-"
  role        = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = ["s3:GetObject", "s3:ListBucket"]
      Effect = "Allow"
      Resource = [
        aws_s3_bucket.website.arn,
        "${aws_s3_bucket.website.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name_prefix = "${var.project_name}-ec2-"
  role        = aws_iam_role.ec2.name
}

# ─────────────────────────────────────────────
# ALB — Application Load Balancer (community module)
# ─────────────────────────────────────────────
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  vpc_id             = var.vpc_id
  subnets            = var.public_subnets
  security_groups    = [var.alb_security_group_id]

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "app"
      }
    }
  }

  target_groups = {
    app = {
      name_prefix       = "app-"
      protocol          = "HTTP"
      port              = 80
      target_type       = "instance"
      create_attachment = false

      health_check = {
        enabled             = true
        healthy_threshold   = 2
        interval            = 30
        matcher             = "200"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 3
      }
    }
  }
}

# ─────────────────────────────────────────────
# AMI — Latest Amazon Linux 2023
# ─────────────────────────────────────────────
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ─────────────────────────────────────────────
# Launch Template — EC2 instance configuration
# ─────────────────────────────────────────────
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [var.ec2_security_group_id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Update and install nginx
    dnf update -y
    dnf install -y nginx

    # Remove default nginx welcome page
    rm -f /usr/share/nginx/html/index.html

    # Pull portfolio website from S3 (copy to nginx html directory)
    aws s3 cp s3://${aws_s3_bucket.website.bucket}/website/ /usr/share/nginx/html/ --recursive

    # Set correct ownership
    chown -R nginx:nginx /usr/share/nginx/html/

    # Start and enable nginx
    systemctl start nginx
    systemctl enable nginx

    # Log completion
    echo "$(date): Website deployment complete" >> /var/log/user-data.log
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-web"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ─────────────────────────────────────────────
# ASG — Auto Scaling Group
# ─────────────────────────────────────────────
resource "aws_autoscaling_group" "app" {
  name_prefix = "${var.project_name}-"

  min_size         = 1
  max_size         = 2
  desired_capacity = 1

  vpc_zone_identifier = var.public_subnets
  target_group_arns   = [module.alb.target_groups["app"].arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg"
    propagate_at_launch = true
  }
}
