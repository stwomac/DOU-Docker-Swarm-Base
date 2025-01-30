# gets the current region the provider is working in
data "aws_region" "current" {}

# gets the availability zones available to this region
data "aws_availability_zones" "available" {}


# sets the info of the ami the images will run off of
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}