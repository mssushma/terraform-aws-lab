output "instance_id" {
  value = aws_instance.server.id
}

output "elastic_ip" {
  value = aws_eip.server_eip.public_ip
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}
