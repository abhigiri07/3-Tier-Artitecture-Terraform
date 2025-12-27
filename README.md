# 3-Tier Architecture on AWS using Terraform

### Project Overview

This project creates a **3-Tier Architecture** on **AWS** using **Terraform (Infrastructure as Code)**.

The architecture is divided into:
1. **Presentation Tier (Web Layer)**
2. **Application Tier (App Layer)**
3. **Database Tier (DB Layer)**

Terraform is used to **automate**, **manage**, and **provision** all AWS resources in a repeatable way.

---

### What is 3-Tier Architecture?

A **3-tier architecture** separates an application into three layers:

| Tier | Purpose |
|----|----|
| Web Tier | Handles user requests (HTTP/HTTPS) |
| App Tier | Processes business logic |
| Database Tier | Stores application data |

This design improves:
- Scalability
- Security
- Availability
- Maintainability

---

### Technologies Used

- **Terraform**
- **AWS**
  - EC2
  - Security Groups
  - VPC
  - Subnets
  - Route Tables
  - Internet Gateway
  - NAT Gateway
  - Elastic IP
  
- **Linux (Amazon Linux 2)**

---

### Architecture Diagram (Logical)

User <br>
│<br>
▼<br>
Internet Gateway<br>
│<br>
▼<br>
Application Load Balancer (Public Subnet)<br>
│<br>
▼<br>
Web Tier (EC2 / Auto Scaling)<br>
│<br>
▼<br>
App Tier (EC2 - Private Subnet)<br>
│<br>
▼<br>
Database Tier (EC2 - Private Subnet)

---

### Project Folder Structure
3-tier-architecture-terraform/<br>
│<br>
├── main.tf<br>
├── provider.tf<br>
├── variables.tf<br>
├── outputs.tf

---
### Files
```main.tf```
```Terraform
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

```

```variable.tf```
```Terraform
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "pri-cidr" {
  default = "10.0.0.0/20"
}
variable "pub-cidr" {
  default = "10.0.16.0/20"
}
variable "az1" {
  default = "us-east-1a"
}
variable "az2" {
  default = "us-east-1b"
}
variable "project_name" {
  default = "FTC"
}
variable "ami" {
  default = "ami-0c02fb55956c7d316"
}
variable "instance_type" {
  default = "t2.micro"
}
variable "key_name" {
  default = "Server101"
}
```
```output.tf```
```Terraform
output "webserver" {
  value = aws_instance.webserver.public_ip
}
output "Appserver" {
  value = aws_instance.Appserver.private_ip
}
output "dbserver" {
  value = aws_instance.dbserver.private_ip
}

```
### Key Components Created
1. VPC
Custom VPC
CIDR block: 10.0.0.0/16

2. Subnets
Public Subnets (Web Tier)
Private Subnets (App Tier)
Private Subnets (DB Tier)

3. Internet Gateway
Allows public internet access for Web Tier

4. Route Tables
Public route table → Internet Gateway
Private route table → Internal traffic only

5. Security Groups
Web SG → Allow HTTP/HTTPS from Internet
App SG → Allow traffic only from Web Tier
DB SG → Allow traffic only from App Tier

6. EC2 Instances
Web Tier EC2 (Public)
App Tier EC2 (Private)

---

### Step-by-Step Deployment Guide
Step-1. Initialize Terraform
```
 terraform init
```
Step-2. Preview Infrastructure (Plan)
```
 terraform plan 
```
Step-3. Apply Infrastructure
```
terraform apply --auto-approve
```
Terraform will now create:

* VPC
* Subnets
* Security Groups
* EC2

Destroy Infrastructure (Cleanup)
```
terraform destroy --auto-approve
```

---

### Conclusion

This project shows how to build a 3-Tier Architecture on AWS using Terraform in a simple and structured way.
It uses Infrastructure as Code to create a secure, scalable, and highly available setup.
The Web, App, and Database layers are properly isolated for better security and performance.
Terraform makes the infrastructure easy to deploy, manage, and destroy.
This project helps in understanding real-world AWS architecture and DevOps practices.
It is a strong learning and portfolio project for Cloud and DevOps beginners.

---

