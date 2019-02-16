variable bastion_hostname  { }
variable bastion_public_ip { }
variable domainname        { }
variable subdomainname     { }
variable tags              { default = {} }


# This already exists! Use it.
data "aws_route53_zone" "domain" {
  name = "${var.domainname}"
}

resource "aws_route53_zone" "subdomain" {
  name = "${var.subdomainname}.${var.domainname}"
  tags = "${var.tags}"
}

# subdomain's NS record
resource "aws_route53_record" "subdomain-NS" {
  zone_id = "${data.aws_route53_zone.domain.zone_id}"
  name    = "${var.subdomainname}.${var.domainname}"
  type    = "NS"
  ttl     = "300"
  records = [
    "${aws_route53_zone.subdomain.name_servers.0}",
    "${aws_route53_zone.subdomain.name_servers.1}",
    "${aws_route53_zone.subdomain.name_servers.2}",
    "${aws_route53_zone.subdomain.name_servers.3}",
  ]
}

# bastion's A record
resource "aws_route53_record" "bastion-A" {
  name    = "${var.bastion_hostname}.${var.subdomainname}.${var.domainname}"
  records = ["${var.bastion_public_ip}"]
  ttl     = "300"
  type    = "A"
  zone_id = "${aws_route53_zone.subdomain.zone_id}"
}
