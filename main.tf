# define AWS provider
provider "aws" {
  region = var.region
}

# Data source: query the list of AZs that are available
data "aws_availability_zones" "available" {
  state = "available"
}

# Get latest Amazon Linux 2 AMI ID
data "aws_ami" "latest_amazon_linux" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Render script from template file
data "template_file" "user_data" {
  template = file("${path.module}/user_data.sh")
}

# NOTE: ONLY CREATE THESE RESOURCES IF YOU HAVE AWS Shield Advanced SUBSCRIPTION ($3000+)
# # Enable AWS Shield Advanced on the AWS resources
# resource "aws_shield_protection" "alb_shield" {
#   name         = "alb-protection"
#   resource_arn = aws_lb.origin.arn
#   depends_on   = [aws_lb.origin]
# }

# resource "aws_shield_protection" "cf_shield" {
#   name         = "cf-protection"
#   resource_arn = aws_cloudfront_distribution.cf.arn
#   depends_on   = [aws_cloudfront_distribution.cf]
# }

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}

# Create security groups that only allow specific ports and sources
resource "aws_security_group" "web" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.ec2_ingress_cidrs
  }

  # Allow SSH from VPC CIDR
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create public subnets in VPC  
resource "aws_subnet" "app" {
  count = length(data.aws_availability_zones.available.names)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index * 5}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Create public route table for Internet access
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate public subnets with public route table 
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.app)
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_lb" "origin" {
  name               = "origin-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.app[*].id
  security_groups    = [aws_security_group.web.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.origin.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.origin.arn
  }
}

resource "aws_lb_target_group" "origin" {
  name     = "origin-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

# Create launch template for web servers
resource "aws_launch_template" "origin" {
  name          = "origin-lt"
  instance_type = var.instance_type
  image_id      = data.aws_ami.latest_amazon_linux.id
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web.id]
  }

  user_data = base64encode(data.template_file.user_data.rendered)
}

# Create autoscaling group 
resource "aws_autoscaling_group" "origin" {
  name                = "origin-asg"
  vpc_zone_identifier = aws_subnet.app.*.id
  health_check_type   = "ELB"

  desired_capacity = var.asg_desired_capacity
  max_size         = var.asg_max_size
  min_size         = var.asg_min_size

  target_group_arns = [aws_lb_target_group.origin.arn]

  launch_template {
    id      = aws_launch_template.origin.id
    version = "$Latest"
  }
}

# Attach ASG to load balancer
resource "aws_autoscaling_attachment" "origin" {
  autoscaling_group_name = aws_autoscaling_group.origin.id
  alb_target_group_arn   = aws_lb_target_group.origin.arn
}


# Create a CloudFront distribution in front of the origin servers 
resource "aws_cloudfront_distribution" "cf" {

  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name = aws_lb.origin.dns_name
    origin_id   = aws_lb.origin.id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_lb.origin.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"

  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE", "PH"]
    }
  }
}

resource "aws_wafv2_web_acl" "waf_acl" {
  name  = "web-acl"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "size-based-rule"
    priority = 1

    action {
      block {}
    }

    statement {
      size_constraint_statement {
        field_to_match {
          body {}
        }

        comparison_operator = "GT"
        size                = "10240"
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "sizeRuleMetrics"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "geo-match-rule"
    priority = 2

    action {
      block {}
    }

    statement {
      geo_match_statement {
        country_codes = var.geo_match_countries
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "geoMatchRuleMetrics"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "detect-sqli"
    priority = 3

    action {
      block {}
    }

    statement {
      sqli_match_statement {
        field_to_match {
          body {}
        }
        text_transformation {
          priority = 1
          type     = "URL_DECODE"
        }
        text_transformation {
          priority = 2
          type     = "HTML_ENTITY_DECODE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "sqliRuleMetrics"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "detect-xss"
    priority = 4

    action {
      block {}
    }

    statement {
      xss_match_statement {
        field_to_match {
          body {}
        }
        text_transformation {
          priority = 1
          type     = "URL_DECODE"
        }
        text_transformation {
          priority = 2
          type     = "HTML_ENTITY_DECODE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "xssRuleMetrics"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "ddosProtectionMetrics"
    sampled_requests_enabled   = true
  }


}

resource "aws_wafv2_web_acl_association" "acl_assoc" {
  resource_arn = aws_lb.origin.arn
  web_acl_arn  = aws_wafv2_web_acl.waf_acl.arn
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.cf.domain_name
}

output "alb_dns_name" {
  value = aws_lb.origin.dns_name
}
