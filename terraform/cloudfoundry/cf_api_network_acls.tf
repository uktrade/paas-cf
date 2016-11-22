resource "aws_network_acl" "cf_api" {
  vpc_id = "${var.vpc_id}"
}

resource "aws_network_acl_rule" "cf_api_whitelist" {
  count = "${length(
    concat(
      compact(split(",", var.admin_cidrs)),
      compact(split(",", var.tenant_cidrs)),
      list(format("%s/32", var.concourse_elastic_ip))
      )
  )}"

  cidr_block = "${element(
    concat(
      compact(split(",", var.admin_cidrs)),
      compact(split(",", var.tenant_cidrs)),
      list(format("%s/32", var.concourse_elastic_ip))
      ),
    count.index
  )}"

  network_acl_id = "${aws_network_acl.cf_api.id}"
  rule_number    = "${100 + count.index}"
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
}

resource "aws_network_acl_rule" "cf_api_blacklist" {
  count = "${length(
    compact(split(",", var.api_blacklist_cidrs))
  )}"

  cidr_block = "${element(
    compact(split(",", var.api_blacklist_cidrs)),
    count.index
  )}"

  network_acl_id = "${aws_network_acl.cf_api.id}"
  rule_number    = "${200 + count.index}"
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
}

resource "aws_network_acl_rule" "cf_api_allowed" {
  count = "${length(
    compact(split(",", var.api_allowed_cidrs))
  )}"

  cidr_block = "${element(
    compact(split(",", var.api_allowed_cidrs)),
    count.index
  )}"

  network_acl_id = "${aws_network_acl.cf_api.id}"
  rule_number    = "${32000 + count.index}"
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
}
