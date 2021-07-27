output "vpcid" {
  value = aws_vpc.myvpc.id
}

output "ec2ip" {
  value = aws_instance.myec2.private_ip
}