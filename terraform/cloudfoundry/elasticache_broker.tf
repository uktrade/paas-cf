resource "aws_security_group" "elasticache_broker_instance_clients" {
  name        = "${var.env}-elasticache-broker-instance-clients"
  description = "Group for clients of RDS broker DB instances"
  vpc_id      = "${var.vpc_id}"

  tags {
    Name = "${var.env}-elasticache-broker-instance-clients"
  }
}

resource "aws_security_group" "elasticache_broker_instances" {
  name        = "${var.env}-elasticache-broker-instances"
  description = "Group for RDS broker DB instances"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port = 6379
    to_port   = 6379
    protocol  = "tcp"

    security_groups = [
      "${aws_security_group.elasticache_broker_instance_clients.id}",
    ]
  }

  tags {
    Name = "${var.env}-elasticache-broker-instances"
  }
}
