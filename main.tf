provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "myvpc" {
  cidr_block = "172.16.0.0/16"

  tags = {
    Name = "public_vpc"
  }
}

resource "aws_subnet" "my_subnet" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = "172.16.10.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "isolated_subnet"
  }
}

resource "aws_instance" "myec2" {
  ami           = "ami-0dc2d3e4c0f9ebd18"
  instance_type = "t2.micro"
  //security_groups = ["allow_tls","allow_rdp"]

  credit_specification {
    cpu_credits = "unlimited"
  }

  tags = {
    Name = "primary_instance"
  }
}

output "vpcid" {
  value = aws_vpc.myvpc.id
}

output "ec2ip" {
  value = aws_instance.myec2.private_ip
}

