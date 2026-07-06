aws_region = "ap-south-1"

availability_zones = [
  "ap-south-1a",
  "ap-south-1b"
]

vpc_cidr = "10.0.0.0/16"

public_subnet_1 = "10.0.1.0/24"
public_subnet_2 = "10.0.2.0/24"

private_subnet_1 = "10.0.3.0/24"
private_subnet_2 = "10.0.4.0/24"

az_1 = "ap-south-1a"
az_2 = "ap-south-1b"

execution_role_arn = "arn:aws:iam::123456789012:role/ecsTaskExecutionRole"

db_username = "postgres"
db_password = "postgres123"
db_name     = "hotel_db"