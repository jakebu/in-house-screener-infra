variable "default_region" {
    type = string
    default = "us-east-1"
}

variable "default_az" {
    type = string
    default = "us-east-1a"
}

variable "ssm_schedule" {
    type = string
    default = "cron(0 15 ? * SUN *)"
}

variable "vpc_cidr" {
    type = string
    default = "172.16.0.0/16"
}

variable "subnet_cidr" {
    type = string
    default = "172.16.10.0/24"
}

variable "default_ip" {
    type = string
    default = "172.16.10.100"
}

variable "default_ami" {
    type = string
    default = "ami-01e4c18598be12113" // Windows Server 2025 Core Base x64
}

variable "default_instance_type" {
    type = string
    default = "t3.micro"
}