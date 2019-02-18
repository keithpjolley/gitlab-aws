variable name_prefix     { default = "gitlab-application-" }
variable image_id        { default = "" }
variable instance_type   { default = "" }
variable security_groups { default = [] }
variable key_name        { default = "" }
variable tags            { default = "" }

/*
data "aws_ami" "gitlab_application_ami" {
  filter {
    name   = "state"
    values = ["available"]
  }
  filter {
    name   = "tag:Name"
    values = ["Replicant_Zero"]
  }
  most_recent = true
}
*/

resource "aws_launch_configuration" "gitlab_application" {
  name_prefix     = "${var.name}-gitlab-application-"
  image_id        = "${var.gitlab_application_ami}"
  instance_type   = "${var.instance_type}"
  security_groups = "${var.security_groups}"
  key_name        = "${var.key_name}"
  tags            = "${var.tags}"
  user_data       = "${data.template_file.gitlab_application_user_data.rendered}"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "gitlab_application" {
  launch_configuration = "${aws_launch_configuration.gitlab_application.name}"
  min_size             = 1
  max_size             = 1
  vpc_zone_identifier  = ["${module.vpc.private_subnets}"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elb" "gitlab_application" {
  subnets         = ["${module.vpc.public_subnets}"]
  security_groups = ["${module.security_groups.external_elb}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 3
    target              = "HTTP:80/-/readiness"
    interval            = 30
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_attachment" "asg_attachment_gitlab" {
  autoscaling_group_name = "${aws_autoscaling_group.gitlab_application.id}"
  elb                    = "${aws_elb.gitlab_application.id}"
}

resource "aws_security_group" "gitlab_application" {
  vpc_id      = "${module.vpc.id}"
  name_prefix = "${var.name}-gitlab-application-"

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = ["${module.security_groups.external_elb}"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

output "gitlab_dns_name" {
  value = "${aws_elb.gitlab_application.dns_name}"
}
