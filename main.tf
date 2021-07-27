provider "aws" {
  region = "us-east-1"
}

// Initial wide range VPC
resource "aws_vpc" "myvpc" {
  cidr_block = "172.16.0.0/16"

  tags = {
    Name = "public_vpc"
  }
}

// Initial private subnet
resource "aws_subnet" "my_subnet" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = "172.16.10.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "isolated_subnet"
  }
}

// SG to allow TLS within VPC
resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.myvpc.cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

// SG to allow RDP within VPC
resource "aws_security_group" "allow_rdp" {
  name        = "allow_rdp"
  description = "Allow RDP inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "RDP from VPC"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.myvpc.cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_rdp"
  }
}

// Create NIC card with specific IP within the private subnet with both SG's attached
resource "aws_network_interface" "my_nic" {
  subnet_id       = aws_subnet.my_subnet.id
  private_ips     = ["172.16.10.100"]
  security_groups = [aws_security_group.allow_rdp.id, aws_security_group.allow_tls.id]

  tags = {
    Name = "primary_network_interface"
  }
}

// Create EC2 using free Windows micro tier 
resource "aws_instance" "myec2" {
  ami           = "ami-03295ec1641924349"
  instance_type = "t2.micro"

// What does unlimited do?
  credit_specification {
    cpu_credits = "unlimited"
  }

  tags = {
    Name = "primary_instance"
  }
}

// Create SSM doc which runs a powershell script "ipconfig"
resource "aws_ssm_document" "my_doc" {
  name          = "my_document"
  document_type = "Command"

  content = <<DOC
  {
    "schemaVersion": "2.2",
    "description": "Check ip configuration of a Windows instance.",
    "mainSteps": [
      {
        "action":"aws:runPowerShellScript",
        "name": "runPowerShellScript",
        "inputs": {
          "runCommand": ["ipconfig"]
        }
      }
    ]
  }
DOC
}

// Create a maintenance window for once a week on Sundays, 2 hour duration, 1 hour cutoff
resource "aws_ssm_maintenance_window" "weekend" {
  name     = "maintenance-window-application"
  schedule = "cron(0 15 ? * SUN *)"
  duration = 2
  cutoff   = 1
}

// Create an S3 bucket to hold results of ssm maintenance window
resource "aws_s3_bucket" "my-bucket-screener-jb-test" {
  bucket = "my-bucket-screener-jb-test"

  tags = {
    Name = "My bucket"
  }
}

// Create SSM task which runs during the SSM window, targeting myec2 and sending output to my-bucket-screener-jb-test S3 bucket
resource "aws_ssm_maintenance_window_task" "my_task" {
  max_concurrency = 2
  max_errors      = 1
  priority        = 1
  task_arn        = "AWS-RunShellScript"
  task_type       = "RUN_COMMAND"
  window_id       = aws_ssm_maintenance_window.weekend.id

  targets {
    key    = "InstanceIds"
    values = [aws_instance.myec2.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      output_s3_bucket     = aws_s3_bucket.my-bucket-screener-jb-test.bucket
      output_s3_key_prefix = "output"
      timeout_seconds      = 600
    }
  }
}

// Specify the SSM window target instance by tag Name primary_instance
resource "aws_ssm_maintenance_window_target" "my_target" {
  window_id     = aws_ssm_maintenance_window.weekend.id
  name          = "maintenance-window-target"
  description   = "This is a maintenance window target"
  resource_type = "INSTANCE"

  targets {
    key    = "tag:Name"
    values = ["primary_instance"]
  }
}

// Associate my_doc SSM doc with myec2
resource "aws_ssm_association" "my_ssm_association" {
  name = aws_ssm_document.my_doc.name

  targets {
    key    = "InstanceIds"
    values = [aws_instance.myec2.id]
  }
}

output "vpcid" {
  value = aws_vpc.myvpc.id
}

output "ec2ip" {
  value = aws_instance.myec2.private_ip
}

