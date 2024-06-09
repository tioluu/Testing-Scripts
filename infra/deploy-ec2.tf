terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# We want to create an ssh into an ubuntu instance
# 1. create a vpc
resource "aws_vpc" "first_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

}

# 2. create internet gateway
resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.first_vpc.id

}

# 3. create a custom route table
resource "aws_route_table" "first-route-table" {
  vpc_id = aws_vpc.first_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gateway.id
  }

}

# 4. create a subnet
resource "aws_subnet" "subnet_1" {
  vpc_id     = aws_vpc.first_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

}

# 5. associate route table and subnet
resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.first-route-table.id
}

# 6. create security group
resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.first_vpc.id

  ingress {
    description      = "HTTPS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 7. create a network interface
resource "aws_network_interface" "nt" {
  subnet_id       = aws_subnet.subnet_1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}

# 8. create an elastic ip address
resource "aws_eip" "eip" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.nt.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [ aws_internet_gateway.gateway, aws_instance.first-instance ]
}


# create the instance and install the server
resource "aws_instance" "first-instance" {
  ami           = "ami-0fc5d935ebf8bc3bc"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "Tolu-New"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.nt.id
  }

  user_data = file("${path.module}/script.sh")
}

# create the second instance and install the server
resource "aws_instance" "first-instance" {
  ami           = "ami-0fc5d935ebf8bc3bc"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "Tolu-New"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.nt.id
  }

  user_data = file("${path.module}/script.sh")
}
