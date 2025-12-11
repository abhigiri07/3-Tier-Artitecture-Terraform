terraform {
  backend "s3" {
    bucket = "terrform-test-bucket-9028"
    key    = ".tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

# Create VPC
resource "aws_vpc" "custom-vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Create Public Subnets
resource "aws_subnet" "pri-subnet" {
  vpc_id            = aws_vpc.custom-vpc.id
  cidr_block        = var.pri-cidr
  availability_zone = var.az1
  depends_on        = [aws_vpc.custom-vpc]
  tags = {
    Name = "${var.project_name}-pri-subnet"
  }
}

# Create Private Subnets
resource "aws_subnet" "pub-subnet" {
  vpc_id                  = aws_vpc.custom-vpc.id
  cidr_block              = var.pub-cidr
  availability_zone       = var.az2
  map_public_ip_on_launch = true
  depends_on              = [aws_vpc.custom-vpc]
  tags = {
    Name = "${var.project_name}-pub-subnet"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "tf-igw" {
  vpc_id = aws_vpc.custom-vpc.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Create elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
   tags = {
    Name = "${var.project_name}-eip"
  }
}

# Create NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.pub-subnet.id
  depends_on    = [aws_internet_gateway.tf-igw]
   tags = {
    Name = "${var.project_name}-nat-gateway"
  }
}


# Create Route Table and Associate with Public Subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.custom-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tf-igw.id
  }

  tags = {
    Name = "${var.project_name}-pub-rt"
  }
}

# Create Route Table and Associate with Private Subnet
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.custom-vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# Associate public Route Table with public Subnets
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.pub-subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Associate private Route Table with private Subnets
resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.pri-subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# Create Security Group for ec2
resource "aws_security_group" "tf-sg" {
  name        = "${var.project_name}-sg"
  description = "Allow SSH, HTTP, and MySQL traffic"
  vpc_id      = aws_vpc.custom-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  depends_on = [aws_vpc.custom-vpc] # explicit dependency
}


# Create Public EC2 Instances
resource "aws_instance" "webserver" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.pub-subnet.id
  vpc_security_group_ids = [aws_security_group.tf-sg.id]
  key_name               = var.key_name
  depends_on             = [aws_security_group.tf-sg]
  tags = {
    Name = "${var.project_name}-Webserver"
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y httpd
              sudo systemctl start httpd
              sudo systemctl enable httpd
              echo "<h1>Welcome to ${var.project_name} Web Server</h1>" > /var/www/html/index.html
              EOF
}

# Create Private AppServer EC2 Instances
resource "aws_instance" "Appserver" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.pri-subnet.id
  vpc_security_group_ids = [aws_security_group.tf-sg.id]
  key_name               = var.key_name
  depends_on             = [aws_security_group.tf-sg]

  tags = {
    Name = "${var.project_name}-Appserver"
  }
}

# Create Private Dbserver EC2 Instances
resource "aws_instance" "dbserver" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.pri-subnet.id
  vpc_security_group_ids = [aws_security_group.tf-sg.id]
  key_name               = var.key_name
  depends_on             = [aws_security_group.tf-sg]

  tags = {
    Name = "${var.project_name}-Dbserver"
  }
}
