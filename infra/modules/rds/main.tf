resource "aws_db_subnet_group" "main" {
  name       = "main"
  subnet_ids = var.private_subnets
}

resource "aws_db_instance" "main" {
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "14"
  instance_class       = var.instance_class
  username             = var.db_username
  password             = var.db_password
  db_name              = var.db_name
  db_subnet_group_name = aws_db_subnet_group.main.name
  skip_final_snapshot  = true
}