variable ami                    { }
variable availability_zones     { default = [] }
variable bastion_public_ip      { }
variable hostname               { default = "nfs_server" }
variable iam_nfs_server         { }
variable instance_type          { default = "t2.micro" }
variable key_name               { }
variable nfs_sec_groups         { default = [] }
variable pem_file               { }
variable prefix                 { }
variable region                 { }
variable tags                   { default = {} }
variable username               { default = "centos" }
variable vpc_cidr               { }
variable vpc_id                 { }
variable vpc_priv_subnets       { default = [] }

locals {
  device_names = ["/dev/xvdf", "/dev/xvdg", "/dev/xvdh"]
}

resource "aws_security_group" "nfs" {
  vpc_id      = "${var.vpc_id}"
  name_prefix = "${var.prefix}-gitlab-nfs-"
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
 }
 ingress {
    from_port   = 111
    to_port     = 111
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = "${var.tags}"
}

resource "aws_instance" "nfs_server" {
  ami                    = "${var.ami}"
  iam_instance_profile   = "${var.iam_nfs_server}"
  instance_type          = "${var.instance_type}"
  key_name               = "${var.key_name}"
  subnet_id              = "${element(var.vpc_priv_subnets, 0)}"
  vpc_security_group_ids = ["${var.nfs_sec_groups}", "${aws_security_group.nfs.id}"]
  tags = "${merge(var.tags, map(
    "Name", "${var.hostname}"
  ))}"
  volume_tags = "${merge(var.tags, map(
    "Name", "${var.hostname}-${format("vol-%03d", count.index+1)}"
  ))}"
}

output "private_ip" {
    value = "${aws_instance.nfs_server.private_ip}"
}

resource "aws_ebs_volume" "gitlab_nfs_volumes" {
  availability_zone = "${element(var.availability_zones, 0)}"
  count             = "${length(local.device_names)}"
  size              = 128  # gigabytes, btw.
  tags = "${var.tags}"
}

#################
# Ansible trigger
resource "null_resource" "nfs_server" {
  triggers {
    nfs_server_id = "${aws_instance.nfs_server.id}"
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
        echo "Giving the NFS server a chance to boot and bring sshd up before proceeding.";
        echo "sleep 30;";
        sleep 30;
      EOF
    ]
  connection {
      user         = "${var.username}"
      host         = "${aws_instance.nfs_server.public_ip}"
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
        -i "${aws_instance.nfs_server.public_ip},"                                                  \
        -u "${var.username}"                                                                        \
        -e "nfs_server_hosts=${aws_instance.nfs_server.public_ip}"                                  \
        -e "bastion_user=${var.username}"                                                           \
        -e "bastion_host=${var.bastion_public_ip}"                                                  \
        -e "instance_id=${aws_instance.nfs_server.id}"                                              \
        -e '{ "volumes": ${jsonencode(aws_ebs_volume.gitlab_nfs_volumes.*.id)} }'                   \
        -e '{ "devices": ${jsonencode(local.device_names)} }'                                       \
        -e region="${var.region}"                                                                   \
        -e cidr="${var.vpc_cidr}"                                                                   \
        ../ansible/nfs/nfs-servers.yml
    EOF

  }
}
