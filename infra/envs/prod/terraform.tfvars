aws_region = "ap-south-1"

vpc_cidr             = "10.1.0.0/16"
public_subnet_cidrs  = ["10.1.0.0/24", "10.1.1.0/24"]
private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]
enable_nat_gateway   = true

container_image = "public.ecr.aws/nginx/nginx:latest"
container_port  = 80
task_cpu        = 1024
task_memory     = 2048
desired_count   = 2

db_engine                = "postgres"
db_engine_version        = "16.3"
db_instance_class        = "db.r6g.large"
db_allocated_storage     = 100
db_max_allocated_storage = 500
db_name                  = "bookings"
db_username              = "app_user"
db_port                  = 5432

# Prod reliability profile: long retention, deletion protection on, Multi-AZ
db_backup_retention_period = 30
db_deletion_protection     = true
db_multi_az                = true

# db_password should be supplied via TF_VAR_db_password or a secrets
# manager - never commit real credentials.
