/*
 * Keith Jolley
 * Mon Feb 11 04:28:17 PST 2019
 */

variable ami                    { }
variable hostname               { default = "appserver-0" }
variable prefix                 { }
variable region                 { }
variable username               { default = "centos" }
variable iam_app_replicant      { }
variable key_name               { }
variable vpc_priv_subnets       { default = [] }
variable sg_app_replicant       { default = [] }
variable instance_type          { default = "t2.large" }

/*
variable iam_nfs_server         { }
variable instance_type          { default = "t2.micro" }
variable availability_zones     { default = [] }
variable bastion_public_ip      { }
variable instance_type          { default = "t2.micro" }
variable key_name               { }
variable nfs_sec_groups         { default = [] }
variable pem_file               { }
variable tags                   { default = {} }
variable vpc_cidr               { }
variable vpc_id                 { }
variable vpc_priv_subnets       { default = [] }
*/

// This creates a single image that I will turn into an AMI.
// Could be done with Packer but that seems like a LOT of 
// overhead for such a simple task.

resource "aws_instance" "app_replicant" {
  ami                    = "${var.ami}"
  iam_instance_profile   = "${var.iam_app_replicant}"
  instance_type          = "${var.instance_type}"
  key_name               = "${var.key_name}"
  subnet_id              = "${element(var.vpc_priv_subnets, 0)}"
  //vpc_security_group_ids = ["${var.sg_app_replicant}", "${aws_security_group.app_replicant.id}"]
  vpc_security_group_ids = ["${var.sg_app_replicant}", "${aws_security_group.app_replicant.id}"]
  tags = "${merge(var.tags, map(
    "Name", "${var.hostname}"
  ))}"
  volume_tags = "${merge(var.tags, map(
    "Name", "${var.hostname}-${format("vol-%03d", count.index+1)}"
  ))}"
}




