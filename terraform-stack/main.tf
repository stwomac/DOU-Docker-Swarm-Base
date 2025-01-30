provider "aws" {
  region = "us-east-1"

  # set tag for every resource due to Account Policy
  default_tags {
    tags = {
      Project = "DockerSwarm"
    }
  }
}

#create private key
resource "tls_private_key" "generic_rsa2048" {
  algorithm = "RSA"
}

# save private key locally
resource "local_file" "private-key-pem" {
  content  = tls_private_key.generic_rsa2048.private_key_pem
  filename = "womackRSA.pem"
}

# create a aws key pair from local private key
resource "aws_key_pair" "generic_rsa2048" {
  key_name   = "womackRSA"
  public_key = tls_private_key.generic_rsa2048.public_key_openssh

  lifecycle {
    ignore_changes = [key_name]
  }
}

# define vpc
resource "aws_vpc" "TerraformVPC" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

# define public subnets
resource "aws_subnet" "public_subnets" {
  for_each          = var.subnets
  vpc_id            = aws_vpc.TerraformVPC.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value["az"] + 100) 
  availability_zone = tolist(data.aws_availability_zones.available.names)[each.value["az"]]
}

# define internet gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.TerraformVPC.id
  tags = {
    Name = "womack-docker-swarm"
  }
}

# set a ip for use in each nat gateway
resource "aws_eip" "swarm_manager" {
  depends_on = [aws_internet_gateway.internet_gateway]
  tags = {
    Name = "ds-manager-eip"
  }

}

# define the route table for public subnet to internet gateway
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.TerraformVPC.id

  route { #assigning route to internet by targeting ID of the IGW above
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
}

# connect public subnets to public route table
resource "aws_route_table_association" "public" {
  depends_on     = [aws_subnet.public_subnets]
  route_table_id = aws_route_table.public_route_table.id
  for_each       = aws_subnet.public_subnets
  subnet_id      = each.value.id
}



# defines security group for docker swarm
resource "aws_security_group" "swarm_sg" {
  name        = "Workers SG - Womack"
  description = "Allow Inbound Traffic"
  vpc_id      = aws_vpc.TerraformVPC.id


  ingress {
    description     = "Allow 2377 TCP for communication with and between manager nodes"
    from_port       = 2377
    to_port         = 2377
    protocol        = "tcp"
    self = true
  }

  ingress {
    description     = "Allow 7946 TCP for overlay network node discovery"
    from_port       = 7946
    to_port         = 7946
    protocol        = "tcp"
    self = true
  }

  ingress {
    description     = "Allow 7946 UDP for overlay network node discovery"
    from_port       = 7946
    to_port         = 7946
    protocol        = "udp"
    self = true
  }

  ingress {
    description     = "Allow 4789 UDP (configurable) for overlay network traffic"
    from_port       = 4789
    to_port         = 4789
    protocol        = "udp"
    self = true
  }

  # Allow access for ssh for debugging
  ingress {
      description     = "Allow 22 from bastion"
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      cidr_blocks = ["47.186.189.83/32"] # access is set to test machine, in production open as you wish
    }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "womack-swarm-sg"
  }
}


resource "aws_instance" "manager1" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public_subnets["1a"].id
  vpc_security_group_ids      = [aws_security_group.swarm_sg.id]
  key_name = aws_key_pair.generic_rsa2048.key_name
  connection {
    user        = "ubuntu"
    private_key = tls_private_key.generic_rsa2048.private_key_pem
    host        = self.public_ip
  }

  # sets up object permissions for windows machine to access host
  provisioner "local-exec" {
    command = "powershell -Command \"(Get-Item '${local_file.private-key-pem.filename}').SetAccessControl((New-Object System.Security.AccessControl.FileSecurity -ArgumentList (Get-Item '${local_file.private-key-pem.filename}').FullName,'ContainerInherit,ObjectInherit'))\""
  }

  tags = {
    Name = "manager1"

  }

    user_data = base64encode(file("user-data.sh"))
}

resource "aws_eip_association" "manager_eip" {
  instance_id = aws_instance.manager1.id
  allocation_id = aws_eip.swarm_manager.id
}

resource "aws_instance" "worker1" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public_subnets["1a"].id
  vpc_security_group_ids      = [aws_security_group.swarm_sg.id]
  key_name = aws_key_pair.generic_rsa2048.key_name
  connection {
    user        = "ubuntu"
    private_key = tls_private_key.generic_rsa2048.private_key_pem
    host        = self.public_ip
  }

  # sets up object permissions for windows machine to access host
  provisioner "local-exec" {
    command = "powershell -Command \"(Get-Item '${local_file.private-key-pem.filename}').SetAccessControl((New-Object System.Security.AccessControl.FileSecurity -ArgumentList (Get-Item '${local_file.private-key-pem.filename}').FullName,'ContainerInherit,ObjectInherit'))\""
  }

  tags = {
    Name = "worker1"

  }

    user_data = base64encode(file("user-data.sh"))
}

resource "aws_instance" "worker2" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public_subnets["1a"].id
  vpc_security_group_ids      = [aws_security_group.swarm_sg.id]
  key_name = aws_key_pair.generic_rsa2048.key_name
  connection {
    user        = "ubuntu"
    private_key = tls_private_key.generic_rsa2048.private_key_pem
    host        = self.public_ip
  }

  # sets up object permissions for windows machine to access host
  provisioner "local-exec" {
    command = "powershell -Command \"(Get-Item '${local_file.private-key-pem.filename}').SetAccessControl((New-Object System.Security.AccessControl.FileSecurity -ArgumentList (Get-Item '${local_file.private-key-pem.filename}').FullName,'ContainerInherit,ObjectInherit'))\""
  }

  tags = {
    Name = "worker2"

  }

    user_data = base64encode(file("user-data.sh"))
}