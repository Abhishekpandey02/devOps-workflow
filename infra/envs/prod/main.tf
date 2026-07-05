provider "aws" {
  region = var.aws_region
}

module "network" {
  source = "../../modules/network"

  vpc_cidr         = var.vpc_cidr
  public_subnet_1  = var.public_subnet_1
  public_subnet_2  = var.public_subnet_2
  private_subnet_1 = var.private_subnet_1
  private_subnet_2 = var.private_subnet_2
  az_1             = var.az_1
  az_2             = var.az_2
}

module "ecs" {
  source = "../../modules/ecs"

  cluster_name       = "prod-cluster"
  private_subnets    = module.network.private_subnets
  execution_role_arn = var.execution_role_arn
}

module "rds" {
  source = "../../modules/rds"

  private_subnets = module.network.private_subnets
  instance_class  = "db.t3.small"
  db_username     = var.db_username
  db_password     = var.db_password
  db_name         = var.db_name
}