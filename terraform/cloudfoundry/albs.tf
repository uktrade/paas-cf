resource "aws_lb" "cf_router_alb" {
  name               = "${var.env}-cf-router"
  internal           = false
  load_balancer_type = "application"
  subnets            = ["${split(",", var.infra_subnet_ids)}"]
  security_groups    = ["${aws_security_group.web.id}"]

  idle_timeout                      = "${var.elb_idle_timeout}"
  enable_cross_zone_load_balancing  = "true"

  access_logs {
    enabled = true
    bucket  = "${aws_s3_bucket.elb_access_log.id}"
    prefix  = "cf-router-alb"
  }
}

resource "aws_lb_target_group" "cf_router" {
  name     = "${var.env}-cf-router-target-group"
  # FIXME: do SSL to gorouter. To do that we need to setup the
  # Go Router to enable the HTTPS endpoint, but also change the tls_port
  # to avoid conflicts with haproxy.
  # tls_port cannot be changed until the latest version of routing_release
  #port     = "8443"
  #protocol = "HTTPS"
  port     = "80"
  protocol = "HTTP"
  vpc_id   = "${var.vpc_id}"

  health_check {
    protocol            = "HTTP"
    port                = "8080"
    path                = "/health"
    matcher             = "200"
    interval            = "${var.health_check_interval}"
    timeout             = "${var.health_check_timeout}"
    healthy_threshold   = "${var.health_check_healthy}"
    unhealthy_threshold = "${var.health_check_unhealthy}"
  }
}

resource "aws_lb_ssl_negotiation_policy" "cf_router_alb" {
  name          = "paas-${var.default_elb_security_policy}"
  load_balancer = "${aws_lb.cf_router_alb.name}"
  lb_port       = 443

  attribute {
    name  = "Reference-Security-Policy"
    value = "${var.default_elb_security_policy}"
  }
}

resource "aws_lb_listener" "cf_router_apps_listener_443" {
  load_balancer_arn = "${aws_lb.cf_router_alb.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2015-05"
  certificate_arn   = "${data.aws_acm_certificate.apps.arn}"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.cf_router.arn}"
  }
}

resource "aws_lb_listener_certificate" "cf_router_system" {
  listener_arn    = "${aws_lb_listener.cf_router_apps_listener_443.arn}"
  certificate_arn = "${data.aws_acm_certificate.system.arn}"
}

resource "aws_lb_listener" "cf_router_listener_80" {
  load_balancer_arn = "${aws_lb.cf_router_alb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port = "443"
      protocol = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
