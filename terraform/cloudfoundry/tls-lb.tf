resource "aws_eip" "cf_router_tls" {
  count = "${var.zone_count}"
  vpc   = true
}

resource "aws_lb" "cf_router_tls" {
  name               = "${var.env}-cf-rtr-tls"
  internal           = false
  load_balancer_type = "network"

  subnet_mapping {
    subnet_id     = "${element(split(",", var.infra_subnet_ids), 0)}"
    allocation_id = "${element(aws_eip.cf_router_tls.*.id, 0)}"
  }

  subnet_mapping {
    subnet_id     = "${element(split(",", var.infra_subnet_ids), 1)}"
    allocation_id = "${element(aws_eip.cf_router_tls.*.id, 1)}"
  }

  subnet_mapping {
    subnet_id     = "${element(split(",", var.infra_subnet_ids), 2)}"
    allocation_id = "${element(aws_eip.cf_router_tls.*.id, 2)}"
  }
}

resource "aws_lb_listener" "cf_router_tls_8080" {
  load_balancer_arn = "${aws_lb.cf_router_tls.arn}"
  port              = "8080"
  protocol          = "TLS"

  ssl_policy      = "${var.default_elb_security_policy}"
  certificate_arn = "${aws_acm_certificate.tls_apps.arn}"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.cf_router_tls_8080.arn}"
  }
}

resource "aws_lb_target_group" "cf_router_tls_8080" {
  name     = "${var.env}-rtr-8080"
  port     = 8080
  protocol = "TCP"
  vpc_id   = "${var.vpc_id}"

  health_check {
    protocol = "TCP"
  }

  lifecycle {
    create_before_destroy = true
  }
}

output "cf_router_tls_8080_target_group_name" {
  value = "${aws_lb_target_group.cf_router_tls_8080.name}"
}
