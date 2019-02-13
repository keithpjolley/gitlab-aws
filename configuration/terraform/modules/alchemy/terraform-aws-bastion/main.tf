/*
 * 
 * The bastion host acts as the "jump point" for the rest of the infrastructure.
 * Since most of our instances aren't exposed to the public internet, the bastion
 * acts as the gatekeeper for any direct SSH access.
 * The bastion is provisioned using the key name that you pass to the stack (and hopefully have stored somewhere).
 * If you ever need to access an instance directly, you can do it by "jumping through" the bastion.
 *
 *    $ terraform output # print the bastion ip
 *    $ ssh -i <path/to/key> centos@<bastion-ip> ssh centos@<internal-ip>
 *
 * https://raw.githubusercontent.com/alchemy-aws-modules/terraform-aws-bastion/master/main.tf
 *
 * Modified a bit by Keith Jolley for more direct/consistent naming.
 */

variable "hostname" {}

variable "instance_type" {
  default     = "t2.micro"
  description = "Instance type, see a list at: https://aws.amazon.com/ec2/instance-types/"
}

variable "security_groups" {
  description = "a comma separated string of security group IDs"
  default     = ""
}

variable "key_name" {
  description = "The SSH key pair, key name"
}

variable "subnet_id" {
  description = "A public subnet id"
}

variable "environment" {
  description = "Environment tag, e.g prod"
}

variable "tags" {
  description = "A map of tags to apply to all resources"
  default     = {}
}

variable "ami" {
  default     = ""
  description = "(Optional) Specify an ami_id for the bastion you would like to use."
}

data "aws_ami" "centos" {
  most_recent = true
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "product-code"
    values = ["aw0evgkw8e5c1q413zgy5pjce"]
  }
  owners = ["aws-marketplace"]
}

resource "aws_instance" "bastion" {
  ami                    = "${length(var.ami) > 0 ? var.ami : data.aws_ami.centos.id}"
  source_dest_check      = false
  instance_type          = "${var.instance_type}"
  subnet_id              = "${var.subnet_id}"
  key_name               = "${var.key_name}"
  vpc_security_group_ids = ["${split(",",var.security_groups)}"]
  monitoring             = true

  tags = "${merge(var.tags, map(
    "Name", "${var.hostname}",
    "Environment", var.environment
  ))}"
  volume_tags = "${merge(var.tags, map(
    "Name", "${var.hostname}-${format("vol-%03d", count.index+1)}",
    "Environment", var.environment
  ))}"
}

resource "aws_eip" "bastion" {
  instance = "${aws_instance.bastion.id}"
  vpc      = true

  tags = "${merge(var.tags, map(
    "Name", "${var.hostname}-eip",
    "Environment", var.environment
  ))}"
}

output "public_ip" {
  value = "${aws_eip.bastion.public_ip}"
}
