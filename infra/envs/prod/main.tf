terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Plan-only review environment: backend left as "local" so `terraform init`
  # and `terraform plan` work without needing real AWS-hosted state.
  # See backend.tf.example for the production-style S3 + DynamoDB configuration.
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  name_prefix = "bookings-prod"
  common_tags = {
    Project     = "hotel-bookings"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

module "network" {
  source = "../../modules/network"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  container_port       = var.container_port
  db_port              = var.db_port
  tags                 = local.common_tags
}

module "rds" {
  source = "../../modules/rds"

  name_prefix            = local.name_prefix
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  max_allocated_storage  = var.db_max_allocated_storage
  db_name                = var.db_name
  db_username            = var.db_username
  db_password            = var.db_password
  db_port                = var.db_port
  private_subnet_ids     = module.network.private_subnet_ids
  rds_security_group_id  = module.network.rds_security_group_id

  # Prod-sized reliability settings: longer retention, deletion protection on, multi-AZ
  backup_retention_period       = var.db_backup_retention_period
  multi_az                      = var.db_multi_az
  deletion_protection           = var.db_deletion_protection
  performance_insights_enabled  = true

  tags = local.common_tags
}

module "ecs" {
  source = "../../modules/ecs"

  name_prefix            = local.name_prefix
  aws_region             = var.aws_region
  vpc_id                 = module.network.vpc_id
  public_subnet_ids      = module.network.public_subnet_ids
  private_subnet_ids     = module.network.private_subnet_ids
  alb_security_group_id  = module.network.alb_security_group_id
  ecs_security_group_id  = module.network.ecs_security_group_id
  container_image        = var.container_image
  container_port         = var.container_port
  task_cpu               = var.task_cpu
  task_memory            = var.task_memory
  desired_count          = var.desired_count
  log_retention_days     = 90

  container_environment = {
    DB_HOST = module.rds.db_address
    DB_NAME = module.rds.db_name
  }

  tags = local.common_tags
}
