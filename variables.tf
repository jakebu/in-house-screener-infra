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
    default = "ami-03295ec1641924349" // Windows Server 2019 x64
}