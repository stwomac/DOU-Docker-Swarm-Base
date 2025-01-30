variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "variable to declare AWS region"
}

variable "vpc_name" {
  type    = string
  default = "womack-docker-swarm"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

# subnets need to have a unified key for nat gateway and internet gateway routing
variable "subnets" {
  default = {
    "1a" = { "public_cidr" : "10.0.101.0/24", private_cidr : "10.0.1.0/24", az = 0 }
    # "1b" = { "public_cidr" : "10.0.102.0/24", private_cidr : "10.0.2.0/24", az = 1 }
  }
}