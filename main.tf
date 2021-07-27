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

  credit_specification {
    cpu_credits = "unlimited"
  }

  tags = {
    Name = "primary_instance"
  }
}

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

resource "aws_ssm_maintenance_window" "weekend" {
  name     = "maintenance-window-application"
  schedule = "cron(0 15 ? * SUN *)"
  duration = 2
  cutoff   = 1
}

resource "aws_s3_bucket" "my-bucket-screener-jb-test" {
  bucket = "my-bucket-screener-jb-test"

  tags = {
    Name = "My bucket"
  }
}

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

