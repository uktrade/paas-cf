resource "aws_elb" "s3_broker" {
  name                      = "${var.env}-s3-broker"
  subnets                   = ["${split(",", var.infra_subnet_ids)}"]
  idle_timeout              = "${var.elb_idle_timeout}"
  cross_zone_load_balancing = "true"
  internal                  = true
  security_groups           = ["${aws_security_group.service_brokers.id}"]

  access_logs {
    bucket        = "${aws_s3_bucket.elb_access_log.id}"
    bucket_prefix = "cf-broker-s3"
    interval      = 5
  }

  health_check {
    target              = "HTTP:80/healthcheck"
    interval            = "${var.health_check_interval}"
    timeout             = "${var.health_check_timeout}"
    healthy_threshold   = "${var.health_check_healthy}"
    unhealthy_threshold = "${var.health_check_unhealthy}"
  }

  listener {
    instance_port      = 80
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = "${data.aws_acm_certificate.system.arn}"
  }
}

resource "aws_lb_ssl_negotiation_policy" "s3_broker" {
  name          = "paas-${var.default_elb_security_policy}"
  load_balancer = "${aws_elb.s3_broker.id}"
  lb_port       = 443

  attribute {
    name  = "Reference-Security-Policy"
    value = "${var.default_elb_security_policy}"
  }
}

resource "aws_db_subnet_group" "s3_broker" {
  name        = "s3broker-${var.env}"
  description = "Subnet group for S3 broker managed instances"
  subnet_ids  = ["${aws_subnet.aws_backing_services.*.id}"]

  tags {
    Name = "s3broker-${var.env}"
  }
}

resource "aws_security_group" "s3_broker_db_clients" {
  name        = "${var.env}-s3-broker-db-clients"
  description = "Group for clients of S3 broker DB instances"
  vpc_id      = "${var.vpc_id}"

  tags {
    Name = "${var.env}-s3-broker-db-clients"
  }
}

resource "aws_security_group" "s3_broker_dbs" {
  name        = "${var.env}-s3-broker-dbs"
  description = "Group for S3 broker DB instances"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"

    security_groups = [
      "${aws_security_group.s3_broker_db_clients.id}",
    ]
  }

  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"

    security_groups = [
      "${aws_security_group.s3_broker_db_clients.id}",
    ]
  }

  tags {
    Name = "${var.env}-s3-broker-dbs"
  }
}

resource "aws_db_parameter_group" "s3_broker_postgres95" {
  name        = "s3broker-postgres95-${var.env}"
  family      = "postgres9.5"
  description = "S3 Broker Postgres 9.5 parameter group"

  parameter {
    apply_method = "pending-reboot"
    name         = "s3.force_ssl"
    value        = "1"
  }

  parameter {
    name  = "s3.log_retention_period"
    value = "10080"                    // 7 days in minutes
  }
}

resource "aws_db_parameter_group" "s3_broker_postgres95_shared_preload_libraries" {
  name        = "s3broker-postgres95-${var.env}-shared-preload-libraries"
  family      = "postgres9.5"
  description = "S3 Broker Postgres 9.5 parameter group with some shared_preload_libraries enabled"

  parameter {
    apply_method = "pending-reboot"
    name         = "s3.force_ssl"
    value        = "1"
  }

  parameter {
    apply_method = "pending-reboot"
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
  }

  parameter {
    name  = "s3.log_retention_period"
    value = "10080"                    // 7 days in minutes
  }
}

resource "aws_db_parameter_group" "s3_broker_postgres10" {
  name        = "s3broker-postgres10-${var.env}"
  family      = "postgres10"
  description = "S3 Broker Postgres 10 parameter group"

  parameter {
    apply_method = "pending-reboot"
    name         = "s3.force_ssl"
    value        = "1"
  }

  parameter {
    name  = "s3.log_retention_period"
    value = "10080"                    // 7 days in minutes
  }
}

resource "aws_db_parameter_group" "s3_broker_mysql57" {
  name        = "s3broker-mysql57-${var.env}"
  family      = "mysql5.7"
  description = "S3 Broker MySQL 5.7 parameter group"
}
