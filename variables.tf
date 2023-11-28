variable "region" {
  type    = string
  default = "us-west-2"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "The VPC CIDR value must be valid."
  }
}

variable "asg_desired_capacity" {
  type    = number
  default = 2
}

variable "asg_max_size" {
  type    = number
  default = 4
}

variable "asg_min_size" {
  type    = number
  default = 2
}

variable "alb_ingress_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "ec2_ingress_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "geo_match_countries" {
  type    = list(string)
  default = ["RU", "CN"]
}
