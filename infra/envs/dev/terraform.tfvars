aws_region = "ap-south-1"

vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
enable_nat_gateway   = true

container_image = "public.ecr.aws/nginx/nginx:latest"
container_port  = 80
task_cpu        = 256
task_memory     = 512
desired_count   = 1

db_engine            = "postgres"
db_engine_version    = "16.3"
db_instance_class    = "db.t4g.micro"
db_allocated_storage = 20
db_name              = "bookings"
db_username          = "app_user"
db_port              = 5432

# Dev reliability profile: shorter retention, no deletion protection
db_backup_retention_period = 3
db_deletion_protection     = false

# db_password should be supplied via TF_VAR_db_password or a local
# untracked *.auto.tfvars file - never commit real credentials.

availability_zones = [
  "ap-south-1a",
  "ap-south-1b"
]
