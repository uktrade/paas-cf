resource "aws_elb" "cf_router_system_domain" {
  name                        = "${var.env}-cf-router-system-domain"
  subnets                     = ["${split(",", var.infra_subnet_ids)}"]
  idle_timeout                = "${var.elb_idle_timeout}"
  cross_zone_load_balancing   = "true"
  connection_draining         = true
  connection_draining_timeout = 110

  security_groups = ["${aws_security_group.cf_api_elb.id}"]

  access_logs {
    bucket        = "${aws_s3_bucket.elb_access_log.id}"
    bucket_prefix = "cf-router-system-domain"
    interval      = 5
  }

  health_check {
    target              = "HTTP:82/health"
    interval            = "${var.health_check_interval}"
    timeout             = "${var.health_check_timeout}"
    healthy_threshold   = "${var.health_check_healthy}"
    unhealthy_threshold = "${var.health_check_unhealthy}"
  }

  listener {
    instance_port      = 443
    instance_protocol  = "ssl"
    lb_port            = 443
    lb_protocol        = "ssl"
    ssl_certificate_id = "${data.aws_acm_certificate.system.arn}"
  }
}

resource "aws_lb_ssl_negotiation_policy" "cf_router_system_domain" {
  name          = "paas-${var.default_elb_security_policy}"
  load_balancer = "${aws_elb.cf_router_system_domain.id}"
  lb_port       = 443

  attribute {
    name  = "Reference-Security-Policy"
    value = "${var.default_elb_security_policy}"
  }
}

resource "aws_proxy_protocol_policy" "cf_router_system_domain_haproxy" {
  load_balancer  = "${aws_elb.cf_router_system_domain.name}"
  instance_ports = ["443"]
}

resource "aws_elb" "cf_doppler" {
  name                      = "${var.env}-cf-doppler"
  subnets                   = ["${split(",", var.infra_subnet_ids)}"]
  idle_timeout              = "${var.elb_idle_timeout}"
  cross_zone_load_balancing = "true"

  security_groups = [
    "${aws_security_group.cf_api_elb.id}",
  ]

  access_logs {
    bucket        = "${aws_s3_bucket.elb_access_log.id}"
    bucket_prefix = "cf-doppler"
    interval      = 5
  }

  health_check {
    target              = "TCP:8081"
    interval            = "${var.health_check_interval}"
    timeout             = "${var.health_check_timeout}"
    healthy_threshold   = "${var.health_check_healthy}"
    unhealthy_threshold = "${var.health_check_unhealthy}"
  }

  listener {
    instance_port      = 8081
    instance_protocol  = "tcp"
    lb_port            = 443
    lb_protocol        = "ssl"
    ssl_certificate_id = "${data.aws_acm_certificate.system.arn}"
  }
}

resource "aws_lb_ssl_negotiation_policy" "cf_doppler" {
  name          = "paas-${var.default_elb_security_policy}"
  load_balancer = "${aws_elb.cf_doppler.id}"
  lb_port       = 443

  attribute {
    name  = "Reference-Security-Policy"
    value = "${var.default_elb_security_policy}"
  }
}

resource "aws_elb" "cf_router" {
  name                      = "${var.env}-cf-router"
  subnets                   = ["${split(",", var.infra_subnet_ids)}"]
  idle_timeout              = "${var.elb_idle_timeout}"
  cross_zone_load_balancing = "true"

  security_groups = ["${aws_security_group.web.id}"]

  access_logs {
    bucket        = "${aws_s3_bucket.elb_access_log.id}"
    bucket_prefix = "cf-router"
    interval      = 5
  }

  health_check {
    target              = "HTTP:82/health"
    interval            = "${var.health_check_interval}"
    timeout             = "${var.health_check_timeout}"
    healthy_threshold   = "${var.health_check_healthy}"
    unhealthy_threshold = "${var.health_check_unhealthy}"
  }

  listener {
    instance_port      = 443
    instance_protocol  = "ssl"
    lb_port            = 443
    lb_protocol        = "ssl"
    ssl_certificate_id = "${aws_acm_certificate_validation.apps.certificate_arn}"
  }

  listener {
    lb_port           = "80"
    lb_protocol       = "http"
    instance_port     = "83"
    instance_protocol = "http"
  }
}

resource "aws_lb_ssl_negotiation_policy" "cf_router" {
  name          = "paas-${var.default_elb_security_policy}"
  load_balancer = "${aws_elb.cf_router.id}"
  lb_port       = 443

  attribute {
    name  = "Reference-Security-Policy"
    value = "${var.default_elb_security_policy}"
  }
}

resource "aws_proxy_protocol_policy" "http_haproxy" {
  load_balancer  = "${aws_elb.cf_router.name}"
  instance_ports = ["443"]
}

resource "aws_elb" "ssh_proxy" {
  name                      = "${var.env}-ssh-proxy"
  subnets                   = ["${split(",", var.infra_subnet_ids)}"]
  idle_timeout              = "${var.elb_idle_timeout}"
  cross_zone_load_balancing = "true"

  security_groups = [
    "${aws_security_group.sshproxy.id}",
  ]

  health_check {
    target              = "TCP:2222"
    interval            = "${var.health_check_interval}"
    timeout             = "${var.health_check_timeout}"
    healthy_threshold   = "${var.health_check_healthy}"
    unhealthy_threshold = "${var.health_check_unhealthy}"
  }

  listener {
    instance_port     = 2222
    instance_protocol = "tcp"
    lb_port           = 2222
    lb_protocol       = "tcp"
  }
}

resource "aws_elb" "cf-istio-router" {
  name                      = "${var.env}-cf-istio-router"
  subnets                   = ["${split(",", var.infra_subnet_ids)}"]
  idle_timeout              = "${var.elb_idle_timeout}"
  cross_zone_load_balancing = "true"

  security_groups = ["${aws_security_group.web.id}"]

  access_logs {
    bucket        = "${aws_s3_bucket.elb_access_log.id}"
    bucket_prefix = "cf-router"
    interval      = 5
  }

  health_check {
    target              = "HTTP:8002/healthcheck"
    interval            = "${var.health_check_interval}"
    timeout             = "${var.health_check_timeout}"
    healthy_threshold   = "${var.health_check_healthy}"
    unhealthy_threshold = "${var.health_check_unhealthy}"
  }

  listener {
    instance_port      = 443
    instance_protocol  = "ssl"
    lb_port            = 443
    lb_protocol        = "ssl"
    ssl_certificate_id = "${aws_acm_certificate_validation.apps.certificate_arn}"
  }

  listener {
    lb_port           = "80"
    lb_protocol       = "http"
    instance_port     = "80"
    instance_protocol = "http"
  }
}


resource "google_compute_address" "cf-istio-router" {
  name = "${var.env}-cf-istio-router"
}

resource "google_dns_record_set" "cf-istio-router-dns" {
  name       = "*.istio.${google_dns_managed_zone.env_dns_zone.dns_name}"
  depends_on = ["google_compute_address.cf-istio-router"]
  type       = "A"
  ttl        = 300

  managed_zone = "${google_dns_managed_zone.env_dns_zone.name}"

  rrdatas = ["${google_compute_address.cf-istio-router.address}"]
}


output "istio_router_lb_ip" {
  value = "${google_compute_address.cf-istio-router.address}"
}

output "istio_router_target_pool" {
  value = "${google_compute_target_pool.cf-istio-router.name}"
}