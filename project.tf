terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  access_key = ""
  secret_key = ""

}
# Create a VPC

resource "aws_vpc" "my-vpc" {
  tags = {
    Name = "Production vpc"
  }
  cidr_block = "10.0.0.0/16"
}

# Creating a subnet inside a VPC

resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.my-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod_subnet"
  }
}

# Create an internet gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my-vpc.id

  tags = {
    Name = "main"
  }
}

# Creating a route table and referencing all traffic to go through the Internet gateway

resource "aws_route_table" "r" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "main"
  }
}


# Creating a security group

resource "aws_security_group" "allow_webtraffic" {
  name        = "allow_web"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# Creating a network interface

resource "aws_network_interface" "myinterface" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_webtraffic.id]

}

# Creating an Elastic IP

resource "aws_eip" "lb" {
  network_interface = aws_network_interface.myinterface.id
  associate_with_private_ip = "10.0.1.50"
  vpc      = true
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_instance" "newinstance" {
  ami = "ami-096fda3c22c1c990a"
  instance_type = "t2.micro"
  key_name = "main-key"
  tags = {
    Name = "Terraform instance"
  }
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.myinterface.id
  }
  user_data = <<-EOF
		#! /bin/bash
              sudo apt update -y
              sudo apt install -y apache2
              sudo systemctl start apache2
              sudo systemctl enable apache2
              sudo bash -c 'echo your very first web server > /var/www/html/index.html'
              EOF

}
