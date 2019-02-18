variable ami                    { }
variable availability_zones     { default = [] }
variable hostname               { default = "cirunner" }
variable instance_type          { default = "t2.micro" }
variable key_name               { }
variable prefix                 { }
variable region                 { }
variable tags                   { default = {} }
variable username               { default = "centos" }
variable vpc_cidr               { }
variable vpc_id                 { }
variable vpc_priv_subnets       { default = [] }

// leave empty for now.
resource "aws_security_group" "sec_group_cirunner" {
  vpc_id      = "${var.vpc_id}"
  name_prefix = "${var.prefix}-cirunner-
  tags = "${var.tags}"
}

resource "aws_instance" "cirunner" {
  ami                    = "${var.ami}"
  instance_type          = "${var.instance_type}"
  key_name               = "${var.key_name}"
  subnet_id              = "${element(var.vpc_priv_subnets, 0)}"
  vpc_security_group_ids = ["${var.sec_group_cirunner}"]
  tags = "${merge(var.tags, map(
    "Name", "${var.hostname}"
  ))}"
}

output "cirunner_private_ip" {
    value = "${aws_instance.cirunner.private_ip}"
}

resource "null_resource" "cirunner" {
  triggers {
    cirunner_id = "${aws_instance.cirunner.id}"
  }
  provisioner "remote-exec" {
    inline = [
      <<EOF
        while [ ! -f /var/lib/cloud/instance/boot-finished ];
        do
          echo -e "\033[1;36mWaiting for cloud-init...";
          hostname;
          sleep 1;
        done;
        echo "Giving the server a chance to boot and bring sshd up before proceeding.";
        echo "sleep 30;";
        sleep 30;
      EOF
    ]
  connection {
      user         = "${var.username}"
      host         = "${aws_instance.cirunner.public_ip}"
      private_key  = "${file(pathexpand(var.pem_file))}"
      bastion_host = "${var.bastion_public_ip}"
      bastion_user = "${var.username}"
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
      (ssh-keygen -F "${var.bastion_public_ip}"                                                     \
       || ssh-keyscan -H "${var.bastion_public_ip}" >> ~/.ssh/known_hosts;                          \
      ssh-add "${pathexpand(var.pem_file)}";                                                        \
      true);                                                                                        \
      ansible-playbook                                                                              \
        --ssh-extra-args='-A -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'           \
        -i "${aws_instance.cirunner.public_ip},"                                                  \
        -u "${var.username}"                                                                        \
        -e "bastion_user=${var.username}"                                                           \
        -e "bastion_host=${var.bastion_public_ip}"                                                  \
        -e "instance_id=${aws_instance.cirunner.id}"                                              \
        -e region="${var.region}"                                                                   \
        -e cidr="${var.vpc_cidr}"                                                                   \
        ../ansible/cirunner/cirunner.yml
    EOF

  }
}