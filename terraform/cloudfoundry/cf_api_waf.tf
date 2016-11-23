resource "aws_waf_ipset" "cf_cc_ip_whitelist_ipset" {
  name = "cf_cc_ip_whitelist_ipset"

  ip_set_descriptors {
    type  = "IPV4"
    value = "192.0.7.0/24"
  }
}

resource "aws_waf_ipset" "cf_cc_ip_blacklist_ipset" {
  name = "cf_cc_ip_blacklist_ipset"

  ip_set_descriptors {
    type  = "IPV4"
    value = "192.0.8.0/24"
  }
}

resource "aws_waf_rule" "cf_cc_ip_whitelist_waf_rule" {
  name        = "cf_cc_ip_whitelist_waf_rule"
  metric_name = "cfccipwhitelistwafrule"

  predicates {
    data_id = "${aws_waf_ipset.cf_cc_ip_whitelist_ipset.id}"
    negated = false
    type    = "IPMatch"
  }
}

resource "aws_waf_rule" "cf_cc_ip_blacklist_waf_rule" {
  name        = "cf_cc_ip_blacklist_waf_rule"
  metric_name = "cfccipblacklistwafrule"

  predicates {
    data_id = "${aws_waf_ipset.cf_cc_ip_blacklist_ipset.id}"
    negated = false
    type    = "IPMatch"
  }
}

resource "aws_waf_web_acl" "cf_cc_ip_blocking_waf_acl" {
  name        = "cf_cc_ip_blocking_waf_acl"
  metric_name = "cfccipblockingwafacl"

  default_action {
    type = "ALLOW"
  }

  rules {
    action {
      type = "BLOCK"
    }

    priority = 2
    rule_id  = "${aws_waf_rule.cf_cc_ip_blacklist_waf_rule.id}"
  }

  rules {
    action {
      type = "ALLOW"
    }

    priority = 1
    rule_id  = "${aws_waf_rule.cf_cc_ip_whitelist_waf_rule.id}"
  }
}
