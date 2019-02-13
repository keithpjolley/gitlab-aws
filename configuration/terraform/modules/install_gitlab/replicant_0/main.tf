/*
 * Keith Jolley
 * Mon Feb 11 04:28:17 PST 2019
 */

// This creates a single image that I will turn into an AMI.
// Could be done with Packer but that seems like a LOT of 
// overhead for such a simple task.

// Use hardcoded `data` instead
// variable ami { default = ""}

variable region        { default = "us-west-2" }
variable profile       { default = "install-gitlab" }
variable instance_type { default = "t2.large" }
variable name          { default = "replicant-0"}
variable version       { default = "0.1"}
variable username      { default = "centos"}

variable pem_file      { default = "~/.aws/install-gitlab.us-west-1.pem" }
variable key_name      { default = "aws-sdfa" }

provider "aws" {
  region  = "${var.region}"
  profile = "${var.profile}"
  version = "~> 1.57"
}

// Delete this section when its time to integrate.
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

// Create a generic instance
resource "aws_instance" "app_replicant_0" {
  ami           = "${data.aws_ami.centos.id}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.key_name}"
  tags = {
    Section = "Replicant Zero"
    Name    = "${var.name}"
    Prefix  = "${var.profile}-${var.region}"
    Version = "${var.version}"
  }
}

# Cut & Paste from nfs/main.tf
#################
# Ansible trigger

resource "null_resource" "app_replicant_0" {
  triggers {
    app_replicant_0 = "${aws_instance.app_replicant_0.id}"
  }
  provisioner "remote-exec" {
    inline = [
      <<EOF
        while [ ! -f /var/lib/cloud/instance/boot-finished ];
        do
          echo -e "\033[1;36mWaiting for cloud-init...";
          hostname;
          sleep 5;
        done;
      EOF
    ]
  connection {
      user = "${var.username}"
      host = "${aws_instance.app_replicant_0.public_ip}"
    }
  }
  # `local` refers to the host that is running terraform
  # Success!!!!  This bit of ssh tomfoolery was what was needed to get this to work without
  # intervention. The ssh-keygen checks if we've got a key for the bastion host, if not,
  # it gets it. The ssh-add makes sure we have our private key in our envionronment. Finally,
  # the "--ssh-extra-args" forward our credentials and turn off having to manually enter "OK"
  # on our first login to the host.
  provisioner "local-exec" {
    command = <<EOF
      ansible-playbook                                                                              \
        -u "${var.username}"                                                                        \
        -i "${aws_instance.app_replicant_0.public_ip},"                                             \
        "../../../../ansible/gitlab/replicant_0.yml"
    EOF

  }
}

