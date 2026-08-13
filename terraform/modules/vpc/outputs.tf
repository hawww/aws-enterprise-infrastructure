output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "nat_gateway_ips" {
  description = "List of NAT Gateway IPs"
  value       = module.vpc.nat_public_ips
}

output "availability_zones" {
  description = "List of availability zones"
  value       = slice(data.aws_availability_zones.available.names, 0, 2)
}
