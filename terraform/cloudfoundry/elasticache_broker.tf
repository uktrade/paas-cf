resource "aws_security_group" "elasticache_broker_clients" {
  name        = "${var.env}-elasticache-broker-clients"
  description = "Group for clients of instances created by the Elasticache broker"
  vpc_id      = "${var.vpc_id}"

  tags {
    Name = "${var.env}-elasticache-broker-clients"
  }
}

resource "aws_security_group" "elasticache_broker_instances" {
  name        = "${var.env}-elasticache-broker-instances"
  description = "Group for instances created by the Elasticache broker"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port = 6379
    to_port   = 6379
    protocol  = "tcp"

    security_groups = [
      "${aws_security_group.elasticache_broker_clients.id}",
    ]
  }

  tags {
    Name = "${var.env}-elasticache-broker-instances"
  }
}
