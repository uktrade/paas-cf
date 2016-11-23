resource "aws_cloudfront_distribution" "cf_cc_cloudcontroller" {
  origin {
    origin_id   = "cf_cc"
    domain_name = "${aws_elb.cf_cc.dns_name}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled = true
  comment = "CF CC CloudFront"

  # We need logging_config {

  aliases = [
    "api.${var.system_dns_zone_name}",
    "api-cloudfront.${var.system_dns_zone_name}",
  ]
  default_cache_behavior {
    target_origin_id = "cf_cc"

    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["HEAD", "GET"]

    forwarded_values {
      query_string            = true
      query_string_cache_keys = []

      cookies {
        forward = "all"
      }

      headers = ["*"]
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }
  price_class = "PriceClass_100"
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    iam_certificate_id = "${var.system_domain_cloudfront_cert_id}"
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1"
  }

  web_acl_id = "${aws_waf_web_acl.cf_cc_ip_blocking_waf_acl.id}"
}

resource "aws_route53_record" "cf_cc_cloudfront" {
  zone_id = "${var.system_dns_zone_id}"
  name    = "api-cloudfront.${var.system_dns_zone_name}."
  type    = "CNAME"
  ttl     = "60"
  records = ["${aws_cloudfront_distribution.cf_cc_cloudcontroller.domain_name}"]
}
