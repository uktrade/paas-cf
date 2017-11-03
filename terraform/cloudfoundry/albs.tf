
resource "aws_alb" "cf_router" {
  name                      = "${var.env}-cf-router"
  internal                  = false
  subnets                   = ["${split(",", var.infra_subnet_ids)}"]
  idle_timeout              = "${var.elb_idle_timeout}"
  security_groups           = ["${aws_security_group.web.id}"]

  access_logs {
    bucket        = "${aws_s3_bucket.elb_access_log.id}"
    prefix        = "cf-router"
  }
}

resource "aws_alb_target_group" "cf_router_http" {
  name     = "gorouter-http"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${var.vpc_id}"
}

resource "aws_alb_target_group" "cf_router_https" {
  name     = "gorouter-https"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = "${var.vpc_id}"
  health_check {
    path                = "/health"
    port                = 8080
    matcher             = "200"
    protocol            = "HTTP"
    interval            = "${var.health_check_interval}"
    timeout             = "${var.health_check_timeout}"
    healthy_threshold   = "${var.health_check_healthy}"
    unhealthy_threshold = "${var.health_check_unhealthy}"
  }
}

resource "aws_alb_listener" "cf_router_http" {
  load_balancer_arn = "${aws_alb.cf_router.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.cf_router_http.arn}"
    type             = "forward"
  }
}

resource "aws_alb_listener" "cf_router_https" {
  load_balancer_arn = "${aws_alb.cf_router.arn}"
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = "${var.apps_domain_cert_arn}"
  ssl_policy        = "${var.default_elb_security_policy}"

  default_action {
    target_group_arn = "${aws_alb_target_group.cf_router_https.arn}"
    type             = "forward"
  }
}

