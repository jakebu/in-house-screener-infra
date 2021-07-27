provider "aws" {
  region = var.default_region
}

// Initial wide range VPC
resource "aws_vpc" "myvpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "public_vpc"
  }
}

// Initial private subnet
resource "aws_subnet" "my_subnet" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = var.subnet_cidr
  availability_zone = var.default_az

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
  private_ips     = [var.default_ip]
  security_groups = [aws_security_group.allow_rdp.id, aws_security_group.allow_tls.id]

  tags = {
    Name = "primary_network_interface"
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
  schedule = var.ssm_schedule
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
    values = [aws_instance.myec2.tags_all.Name] // "primary_instance"
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

//////////////////////

#Instance Role
resource "aws_iam_role" "ssm_role" {
  name = "test-ssm-ec2"
  assume_role_policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
    {
    "Action": "sts:AssumeRole",
    "Principal": {
        "Service": "ec2.amazonaws.com"
    },
    "Effect": "Allow",
    "Sid": ""
    }
]
}
EOF

  tags = {
    Name = "test-ssm-ec2"
  }
}

#Instance Profile
resource "aws_iam_instance_profile" "my_profile" {
  name = "test-ssm-ec2"
  role = "${aws_iam_role.ssm_role.id}"
}

#Attach Policies to Instance Role
resource "aws_iam_policy_attachment" "iam_attach_ssm" {
  name       = "test-attachment"
  roles      = [aws_iam_role.ssm_role.id]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy_attachment" "iam_attach_ec2_role" {
  name       = "test-attachment"
  roles      = [aws_iam_role.ssm_role.id]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

// Create EC2 using free Windows micro tier 
resource "aws_instance" "myec2" {
  ami           = var.default_ami
  instance_type = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.my_profile.id
  user_data = "${file("C:\\code\\in-house-screener-infra\\ssm\\install-ssm.ps1")}"

  // What does unlimited do?
  credit_specification {
    cpu_credits = "unlimited"
  }

  tags = {
    Name = "primary_instance"
  }
}