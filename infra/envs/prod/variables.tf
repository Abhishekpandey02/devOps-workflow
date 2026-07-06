variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.0.0/24", "10.1.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.10.0/24", "10.1.11.0/24"]
}

variable "enable_nat_gateway" {
  type    = bool
  default = true
}

variable "container_image" {
  type    = string
  default = "public.ecr.aws/nginx/nginx:latest"
}

variable "container_port" {
  type    = number
  default = 80
}

variable "task_cpu" {
  description = "Prod uses larger task sizing than dev"
  type        = number
  default     = 1024
}

variable "task_memory" {
  type    = number
  default = 2048
}

variable "desired_count" {
  description = "Prod runs multiple tasks for availability"
  type        = number
  default     = 2
}

variable "db_engine" {
  type    = string
  default = "postgres"
}

variable "db_engine_version" {
  type    = string
  default = "16.3"
}

variable "db_instance_class" {
  description = "Prod uses a larger instance class than dev"
  type        = string
  default     = "db.r6g.large"
}

variable "db_allocated_storage" {
  type    = number
  default = 100
}

variable "db_max_allocated_storage" {
  type    = number
  default = 500
}

variable "db_name" {
  type    = string
  default = "bookings"
}

variable "db_username" {
  type      = string
  default   = "app_user"
  sensitive = true
}

variable "db_password" {
  description = "Set via TF_VAR_db_password / a secrets manager - never commit real credentials"
  type        = string
  sensitive   = true
  default     = "change-me-in-prod"
}

variable "db_port" {
  type    = number
  default = 5432
}

variable "db_backup_retention_period" {
  description = "Prod keeps a long backup retention window"
  type        = number
  default     = 30
}

variable "db_deletion_protection" {
  description = "Prod protects the database from accidental deletion"
  type        = bool
  default     = true
}

variable "db_multi_az" {
  description = "Prod runs Multi-AZ for high availability"
  type        = bool
  default     = true
}

variable "availability_zones" {
  description = "Availability Zones"
  type        = list(string)
}