/*
 * Keith Jolley
 * Mon Feb 11 04:28:17 PST 2019
 */

// This creates a single image that I will turn into an AMI.
// Could be done with Packer but that seems like a LOT of 
// overhead for such a simple task.

// Use hardcoded `data` instead
// variable ami { default = ""}
variable ami              { }
variable instance_type    { default = "t2.large" }
variable key_name         { default = "" }
variable name             { default = "replicant_zero"}
variable pem_file         { }
variable tags             { default = {}}
variable username         { default = "centos"}
variable vpc_priv_subnets { default = [] }


// Create a generic instance
resource "aws_instance" "app_replicant_0" {
  ami           = "${var.ami}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.key_name}"
  name          = "${var.name}"
  subnet_id     = "${element(var.vpc_priv_subnets, 0)}"
  tags = "${merge(var.tags,
                map("Instance", "Replicant_Zero"),
                map("Ansible",   "configuration/ansible/gitlab/replicant_0.yml"),
                map("Terraform", "configuration/terraform/modules/install-gitlab/replicant_0"),
                map("WARNING",   "Subject to immediate shutdown without warning!!!!")
         )}"
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
  # Install the gitlab app server software and immediately shutdown so we can create an AMI
  provisioner "local-exec" {
    command = <<EOF
      (ssh-keygen -F "${aws_instance.app_replicant_0.public_ip}"                                   \
       || ssh-keyscan -H "${aws_instance.app_replicant_0.public_ip}" >> ~/.ssh/known_hosts;        \
      ssh-add "${pathexpand(var.pem_file)}";                                                       \
      true);                                                                                       \
      ansible-playbook                                                                             \
        -u "${var.username}"                                                                       \
        -i "${aws_instance.app_replicant_0.public_ip},"                                            \
        "../ansible/gitlab/replicant_0.yml"
      ansible-playbook                                                                             \
        -u "${var.username}"                                                                       \
        -i "${aws_instance.app_replicant_0.public_ip},"                                            \
        "../ansible/gitlab/shutdown.yml"
    EOF
  }
}

# Now go create an ami from this.
