/*
 * Keith Jolley
 * Sun Feb 10 05:05:19 PST 2019
 *
 * This (and all config files) are parsed. As this can be 
 * confusing try to limit all changes to this section and
 * propagate as vars (as intended). Better solution to 
 * create a separate vars file?
 *
 */


/*** Prefix Start *******************************/
__PREFIX__
/*** Prefix End   *******************************/

provider "aws" {
  region  = "${var.region}"
  profile = "${var.profile}"
  version = "~> 1.57"
}

variable "main_cidr" {
  default = "10.33.0.0/20" // hbd, dad!
}
variable "public_subnets"  { default = [ "10.33.0.0/24", "10.33.1.0/24" ] }
variable "private_subnets" { default = [ "10.33.2.0/24", "10.33.3.0/24" ] }

// Use the same image for the different servers
data "aws_ami" "centos" {
  owners      = ["aws-marketplace"]
  most_recent = true
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "product-code"
    values = ["aw0evgkw8e5c1q413zgy5pjce"]
  }
}

module "bastion" {
  source          = "./modules/alchemy/terraform-aws-bastion"
  hostname        = "${var.bastion_hostname}"
  instance_type   = "t2.micro"
  environment     = "${var.prefix}.${var.region}"
  security_groups = "${module.security_groups.external_ssh}"
  key_name        = "${var.keypair}"
  subnet_id       = "${element(module.vpc.public_subnets, 0)}"
  ami             = "${data.aws_ami.centos.id}"
  tags = {
    Section = "Bastion"
    Prefix  = "${var.prefix}"
    Region  = "${var.region}"
    Version = "${var.version}"
  }
}

module "iam" {
  source = "./modules/install_gitlab/iam"
  tags {
    Section = "IAM"
    Prefix  = "${var.prefix}"
    Region  = "${var.region}"
    Version = "${var.version}"
  }
}

module "nfs" {
  source              = "./modules/install_gitlab/nfs"
  ami                 = "${data.aws_ami.centos.id}"
  availability_zones  = ["${var.availability_zone_0}", "${var.availability_zone_1}"]
  bastion_public_ip   = "${module.bastion.public_ip}"
  iam_nfs_server      = "${module.iam.inst_prof_nfs_server}"
  instance_type       = "t2.micro"
  key_name            = "${var.keypair}"
  nfs_sec_groups      = ["${module.security_groups.internal_ssh}"]
  pem_file            = "${var.pemfile}"
  prefix              = "${var.prefix}"
  region              = "${var.region}"
  username            = "${var.username}"
  vpc_cidr            = "${var.main_cidr}"
  vpc_id              = "${module.vpc.id}"
  vpc_priv_subnets    = ["${module.vpc.private_subnets}"]
  tags = {
    Section = "NFS"
    Prefix  = "${var.prefix}"
    Region  = "${var.region}"
    Version = "${var.version}"
  }
}

module "rds" {
  source              = "./modules/install_gitlab/rds"
  availability_zones  = ["${var.availability_zone_0}", "${var.availability_zone_1}"]
  postgress_host_type = "db.m4.large"
  redis_host_type     = "cache.t2.small"
  name                = "${var.prefix}"
  postgress_passwd    = "${var.postgress_passwd}"
  prefix              = "${var.prefix}"
  sg_int_psql         = "${module.security_groups.internal_psql}"
  sg_int_redis        = "${module.security_groups.internal_redis}"
  vpc_default_db_subnet_group = "${module.vpc.default_db_subnet_group}"
  vpc_private_subnets = ["${module.vpc.private_subnets}"]
  tags = {
    Section = "RDS"
    Prefix  = "${var.prefix}"
    Region  = "${var.region}"
    Version = "${var.version}"
  }
}

module "route53" {
  source            = "./modules/install_gitlab/route53"
  bastion_hostname  = "${var.bastion_hostname}"
  bastion_public_ip = "${module.bastion.public_ip}"
  domainname        = "${var.domainname}"
  subdomainname     = "${var.subdomainname}"
  tags = {
    Section = "Route53"
    Prefix  = "${var.prefix}"
    Region  = "${var.region}"
    Version = "${var.version}"
  }
}

module "security_groups" {
  source      = "./modules/alchemy/terraform-aws-security-groups"
  cidr        = "${module.vpc.cidr_block}"
  environment = "${var.prefix}.${var.region}"
  name        = "${var.prefix}"
  vpc_id      = "${module.vpc.id}"
  tags = {
    Section = "Security Groups"
    Prefix  = "${var.prefix}"
    Region  = "${var.region}"
    Version = "${var.version}"
  }
}

module "vpc" {
  source              = "./modules/alchemy/terraform-aws-vpc"
  availability_zones  = ["${var.availability_zone_0}", "${var.availability_zone_1}"]
  cidr                = "${var.main_cidr}"
  environment         = "${var.prefix}.${var.region}"
  name                = "${var.prefix}_vpc"
  nat_instance_ssh_key_name = "${var.keypair}"
  private_subnets     = ["${var.private_subnets}"]
  public_subnets      = ["${var.public_subnets}"]
  use_nat_instances   = true
  version             = "${var.version}"
  tags = {
    Section = "VPC"
    Prefix  = "${var.prefix}"
    Region  = "${var.region}"
    Version = "${var.version}"
  }
}


// `replicant` builds the prototype application server.
// Right now I'm going to run this once and create an AMI.
// Perhaps later it will make sense to do this programmatically
// but there's little bang for the buck.
// Until then, cd into the cource dir and run:
//   terraform init
//   terraform get
//   terraform apply
// This will create the prototype application server (replicant)
// which can be made into an AMI (from the console). This AMI
// will be hardcoded into `bootstrap.py` and copied to different
// regions as needed (zero or one time per region).
// This section is here to explain the above.

//module "replicant" {
//  source              = "./modules/install-gitlab/replicant"
//}

# House-keeping
#############################################
# Resources that have been manually imported.
#
# When terraform tells you it can't create a
# resource its already created, here's how to add:
#
# Terraform says:
# ...
# * module.rds.aws_elasticache_subnet_group.ec_subnet_group_redis: 1 error(s) occurred:
# 
# * aws_elasticache_subnet_group.ec_subnet_group_redis: Error creating CacheSubnetGroup: \
#   CacheSubnetGroupAlreadyExists: Cache subnet group install-gitlab-redis-subnet-group already exists.
#
#   status code: 400, request id: 6d30c098-2db6-11e9-8e24-358089c8950f
# ...
#
# Then do this:
#
# Put the resource in this file (top level main) just as it is
# in the file where the resource is defined, though you probably
# will have to rename `var` to `module`.
#resource "aws_elasticache_subnet_group" "ec_subnet_group_redis" {
#  name = "${var.prefix}_vpc-redis-subnet-group"
#  subnet_ids = ["${module.vpc.private_subnets}"]
#}
#
# Then run: 
#                    (resource definition)                              (resource id)
# $ terraform import aws_elasticache_subnet_group.ec_subnet_group_redis install-gitlab-redis-subnet-group
# 
# And you should be good to go.
