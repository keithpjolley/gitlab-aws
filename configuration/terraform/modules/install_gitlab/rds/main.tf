variable availability_zones  { default = [] }
variable name                { }
variable postgres_host_type  { default = "db.m4.large" }
variable postgres_password   { }
variable prefix              { }
variable redis_host_type     { default = "cache.t2.small" }
variable sg_int_psql         { }
variable sg_int_redis        { }
variable vpc_default_db_subnet_group { }
variable vpc_private_subnets { default = [] }

variable tags                { default = {} }
variable postgres_username   { default = "gitlab" }
variable postgres_dbname     { default = "gitlab_prod" }



# `instance_class` here, `instance_type` everywhere else.
resource "aws_db_instance" "gitlab_postgres" {
  allocated_storage             = 50 # G
  db_subnet_group_name          = "${var.vpc_default_db_subnet_group}"
  engine                        = "postgres"
  engine_version                = "9.6.9"
  identifier_prefix             = "${var.prefix}"
  instance_class                = "${var.postgres_host_type}"
  multi_az                      = true
  name                          = "gitlab_production"
  password                      = "${var.postgres_password}"
  skip_final_snapshot           = true
  storage_encrypted             = true
  storage_type                  = "gp2"
  username                      = "${var.postgres_username}"
  vpc_security_group_ids        = ["${var.sg_int_psql}"]
}

output "gitlab_postgres_dbname" {
  value = "${var.postgres_dbname}"
}

output "gitlab_postgres_username" {
  value = "${var.postgres_username}"
}

output "gitlab_postgres_address" {
  value = "${aws_db_instance.gitlab_postgres.address}"
}

# For some reason terraform loses track of how many of these
# it's made.
variable maxcount { default = 1 }
resource "aws_elasticache_subnet_group" "ec_subnet_group_redis" {
  name = "${var.name}-redis_ec_sg"
  count = "${1 - var.maxcount}"
  subnet_ids = ["${var.vpc_private_subnets}"]
}

# `node_type` here...
resource "aws_elasticache_replication_group" "ec_replicant_group_redis" {
  automatic_failover_enabled    = true
  availability_zones            = ["${var.availability_zones}"]
  engine                        = "redis"
  engine_version                = "3.2.10"
  node_type                     = "${var.redis_host_type}"
  number_cache_clusters         = 2
  parameter_group_name          = "default.redis3.2"
  port                          = 6379
  replication_group_id          = "${var.name}"
  replication_group_description = "${var.name}-ec_replication_group_redis" 
  security_group_ids            = ["${var.sg_int_redis}"]
  subnet_group_name             = ["${aws_elasticache_subnet_group.ec_subnet_group_redis.0.name}"]
}

output "gitlab_redis_primary_endpoint_address" {
  value = "${aws_elasticache_replication_group.ec_replicant_group_redis.primary_endpoint_address}"
}

