output "system_domain_cert_arn" {
  value = "${aws_iam_server_certificate.system.arn}"
}

output "system_domain_cert_id" {
  value = "${aws_iam_server_certificate.system.id}"
}

output "apps_domain_cert_arn" {
  value = "${aws_iam_server_certificate.apps.arn}"
}

output "apps_domain_cert_id" {
  value = "${aws_iam_server_certificate.apps.id}"
}

output "system_domain_cloudfront_cert_arn" {
  value = "${aws_iam_server_certificate.system_cloudfront.arn}"
}

output "system_domain_cloudfront_cert_id" {
  value = "${aws_iam_server_certificate.system_cloudfront.id}"
}

output "apps_domain_cloudfront_cert_arn" {
  value = "${aws_iam_server_certificate.apps_cloudfront.arn}"
}

output "apps_domain_cloudfront_cert_id" {
  value = "${aws_iam_server_certificate.apps_cloudfront.id}"
}
