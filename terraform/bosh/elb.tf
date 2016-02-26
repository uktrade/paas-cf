resource "aws_elb" "bosh" {
  name = "${var.env}-bosh"
  subnets = ["${split(",", var.infra_subnet_ids)}"]
  idle_timeout = 600
  cross_zone_load_balancing = "true"
  internal = "true"
  security_groups = [
    "${aws_security_group.bosh_elb.id}",
  ]

  health_check {
    target = "TCP:22"
    interval = 5
    timeout = 2
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
  listener {
    instance_port = 22
    instance_protocol = "tcp"
    lb_port = 22
    lb_protocol = "tcp"
  }

  listener {
    instance_port = 6868
    instance_protocol = "tcp"
    lb_port = 6868
    lb_protocol = "tcp"
  }

  listener {
    instance_port = 25555
    instance_protocol = "tcp"
    lb_port = 25555
    lb_protocol = "tcp"
  }

  listener {
    instance_port = 4222
    instance_protocol = "tcp"
    lb_port = 4222
    lb_protocol = "tcp"
  }

  listener {
    instance_port = 25250
    instance_protocol = "tcp"
    lb_port = 25250
    lb_protocol = "tcp"
  }

  listener {
    instance_port = 25777
    instance_protocol = "tcp"
    lb_port = 25777
    lb_protocol = "tcp"
  }
}

resource "aws_route53_record" "bosh" {
  zone_id = "${var.system_dns_zone_id}"
  name    = "bosh.${var.env}.${var.system_dns_zone_name}."
  type    = "CNAME"
  ttl     = "60"
  records = ["${aws_elb.bosh.dns_name}"]
}
