provider "aws" {
  region = var.region
}

# Pull Latest Amazon Linux 2023 AMI 

data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# VPC

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "terraform-vpc"
  }
}

# Public Subnet

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

# Private Subnet

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "private-subnet"
  }
}

# Internet Gateway

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terraform-igw"
  }
}

# Route Table

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group

resource "aws_security_group" "ec2_sg" {
  name        = "terraform-ssh-sg"
  description = "Security Group for EC2"
  vpc_id      = aws_vpc.main.id

  # SSH from your IP only
  ingress {
    description = "SSH"

    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    cidr_blocks = ["167.103.72.80/32"]
  }

  # Website access from anywhere
  ingress {
    description = "HTTP"

    from_port   = 80
    to_port     = 80
    protocol    = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-sg"
  }
}

# EC2 INSTANCE

resource "aws_instance" "server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"

  subnet_id = aws_subnet.public.id

  # Explicitly disable automatic public IP
  associate_public_ip_address = false

  vpc_security_group_ids = [
    aws_security_group.ec2_sg.id
  ]

  user_data = <<-EOF
              #!/bin/bash

              yum update -y
              yum install -y httpd

              systemctl enable httpd
              systemctl start httpd

              echo "<h1>Created by Terraform via GitHub Actions</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "github-actions-ec2"
  }
}

# ELASTIC IP

resource "aws_eip" "server_eip" {
  domain = "vpc"

  tags = {
    Name = "github-actions-eip"
  }
}

# ELASTIC IP ASSOCIATION

resource "aws_eip_association" "server_eip_assoc" {
  instance_id   = aws_instance.server.id
  allocation_id = aws_eip.server_eip.id
}
