terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-northeast-2"
}

# Create a VPC
resource "aws_vpc" "devGal-vpc" {
  cidr_block = "10.1.0.0/16"

  tags = {
    Name = "devGal-vpc"
  }
}

# Create a Subnet for vpc
resource "aws_subnet" "public-subnet-a-01" {
  vpc_id            = aws_vpc.devGal-vpc.id
  availability_zone = "ap-northeast-2a"
  cidr_block        = "10.1.1.0/26"
  tags = {
    Name = "devGal-public-subnet-a-01"
  }
}


resource "aws_subnet" "private-subnet-a-01" {
  vpc_id            = aws_vpc.devGal-vpc.id
  availability_zone = "ap-northeast-2a"
  cidr_block        = "10.1.1.128/27"
  tags = {
    Name = "devGal-private-subnet-a-01"
  }
}


resource "aws_subnet" "public-subnet-c-01" {
  vpc_id            = aws_vpc.devGal-vpc.id
  availability_zone = "ap-northeast-2c"
  cidr_block        = "10.1.1.64/26"
  tags = {
    Name = "devGal-public-subnet-c-01"
  }
}



resource "aws_subnet" "private-subnet-c-01" {
  vpc_id            = aws_vpc.devGal-vpc.id
  availability_zone = "ap-northeast-2c"
  cidr_block        = "10.1.1.160/27"
  tags = {
    Name = "devGal-private-subnet-c-01"
  }
}


/* NAT */

# ngw
resource "aws_eip" "ngw-ip" {
  vpc = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_nat_gateway" "devGal-ngw" {
  allocation_id = aws_eip.ngw_ip.id
  subnet_id     = aws_subnet.public-subnet-a-01

  tags = {
    Name = "devGal-nat-public-a"
  }
  depends_on = [aws_internet_gateway.devGal-gw]
}


/* IGW */
resource "aws_internet_gateway" "devGal-gw" {
  vpc_id = aws_vpc.devGal-vpc.id

  tags = {
    Name = "devGal-igw"
  }
}


/* routing table - public subnet route table*/
# route table 생성
resource "aws_route_table" "devGal-public-rt" {
  vpc_id = aws_vpc.devGal-vpc.id

  tags = {
    Name = "devGal-public-rt"
  }
}

# route table과 subnet 연결
resource "aws_route_table_association" "devGal-public-rt-association1" {
  subnet_id      = aws_subnet.public-subnet-a-01
  route_table_id = aws_route_table.devGal-public-rt.id
}

# route table과 subnet 연결
resource "aws_route_table_association" "evGal-public-rt-association2" {
  subnet_id      = aws_subnet.public-subnet-c-01
  route_table_id = aws_route_table.devGal-public-rt.id
}

# route 규칙 추가
resource "aws_route" "devGal-public-rt-rule" {
  route_table_id         = aws_route_table.devGal-public-rt
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.devGal-gw.id
}


/* routing table - private subnet route table*/
# route table 생성
resource "aws_route_table" "devGal-private-rt" {
  vpc_id = aws_vpc.devGal-vpc.id

  tags = {
    Name = "devGal-private-rt"
  }
}

# route table과 subnet 연결
resource "aws_route_table_association" "devGal-private-rt-association1" {
  subnet_id      = aws_subnet.private-subnet-a-01
  route_table_id = aws_route_table.devGal-private-rt.id
}

# route table과 subnet 연결
resource "aws_route_table_association" "evGal-private-rt-association2" {
  subnet_id      = aws_subnet.private-subnet-c-01
  route_table_id = aws_route_table.devGal-private-rt.id
}

# route 규칙 추가
resource "aws_route" "devGal-private-rt-rule" {
  route_table_id         = aws_route_table.devGal-private-rt
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.devGal-ngw.id
}


/* ROUTE 53*/
/* route 53 설정은 콘솔에서 .... */
/*  도메인 지금 테스트하는거에서 쓰고 있어서 나중에 함...... */


/* EC2 - OPEN VPN */
resource "aws_eip" "devGal-vpn-ip" {
  vpc = true

  lifecycle {
    create_before_destroy = true
  }
}

# aws_key_pair resource 설정
resource "aws_key_pair" "vpn-key" {
  # 등록할 key pair의 name
  key_name = "vpn-key"

  # public_key = "{.pub 파일 내용}"
  public_key = file("~/.ssh/terraform_keys/vpn-key.pub")

  tags = {
    Name        = "vpn-key"
    description = "ssh public key for vpn"
  }
}

resource "aws_security_group" "vpn-sg" {
  name        = "allow_tls_and_ssh"
  description = "allow "
  vpc_id      = aws_vpc.devGal-vpc.id

  ingress {
    description = "TLS to VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.devGal-vpc.cidr_block]
  }

  ingress {
    description = "http to VPC"
    from_port   = 943
    to_port     = 945
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.devGal-vpc.cidr_block]
  }
  ingress {
    description = "udp vpn"
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = [aws_vpc.devGal-vpc.cidr_block]
  }

  ingress {
    description = "ssh to VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "ssh"
    cidr_blocks = [aws_vpc.devGal-vpc.cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "vpn_sg"
  }
}



resource "aws_instance" "devGal-vpn" {
  ami             = "ami-0252e942f644326f7"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public-subnet-a-01.id
  allocation_id   = aws_eip.devGal-vpn-ip.id
  key_name        = aws_key_pair.vpn-key
  security_groups = aws_security_group.vpn-sg

  tags = {
    Name = "devGal-vpn-instance"
  }

}



/* EC2 - HELLO API */
# aws_key_pair resource 설정
resource "aws_key_pair" "hello-app-key" {
  # 등록할 key pair의 name
  key_name = "hello-app-key"

  # public_key = "{.pub 파일 내용}"
  public_key = file("~/.ssh/terraform_keys/hello-app-key.pub")

  tags = {
    Name        = "hello-app-key"
    description = "ssh public key for vpn"
  }
}


resource "aws_security_group" "hello-app-sg" {
  name   = "allow_tls_and_ssh"
  vpc_id = aws_vpc.devGal-vpc.id

  ingress {
    description = "TLS from alb "
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.devGal-vpc.cidr_block]
  }

  ingress {
    description = "8080 from alb"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.devGal-vpc.cidr_block]
  }

  ingress {
    description = "80 from alb"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.devGal-vpc.cidr_block]
  }


  ingress {
    description              = "ssh to VPC"
    from_port                = 22
    to_port                  = 22
    protocol                 = "ssh"
    cidr_blocks              = [aws_vpc.devGal-vpc.cidr_block]
    source_security_group_id = aws_security_group.vpn_sg.id
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "hello-app-sg"
  }
}



resource "aws_instance" "devGal-hello-app" {
  ami             = "ami-00f7d9aa0e54b4f59"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.private-subnet-a-01.id
  key_name        = aws_key_pair.hello-app-key
  security_groups = aws_security_group.hello-app-sg

  tags = {
    Name = "devGal-vpn-instance"
  }
}

/* ALB */
resource "aws_security_group" "devGal-alb-sg" {
  name = "devGal-alb-sg"
}

resource "aws_alb_target_group" "alb-target-hello-app" {
  name = "tset-alb-tg"
  port = 433
  protocol = "HTTPS"
  vpc_id = aws_vpc.test.id
}

resource "aws_alb_target_group_attachment" "forward-hello-app" {
  target_group_arn = aws_alb_target_group.alb-target-hello-app.arn
  target_id = aws_instance.devGal-hello-app
  port = 8080
}

resource "aws_alb_listener" "devGal-http-listener" {
  load_balancer_arn = aws_alb.devGal-alb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_alb_target_group.alb-target-hello-app.arn
  }
}

# https -> go to 
resource "aws_lb_listener" "force-https" {
  load_balancer_arn = aws_lb.devGal-alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb" "devGal-alb" {
  name               = "devGal-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.devGal-alb-sg.id]
  subnets            = [aws_subnet.public-subnet-a-01, aws_subnet.public-subnet-c-01]

  enable_cross_zone_load_balancing = true
  enable_deletion_protection = true

  tags = {
    Environment = "test"
    Name        = "test-lb-tf"
  }
}
