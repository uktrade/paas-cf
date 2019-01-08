resource "aws_iam_user" "ci-cd_broker" {
  name = "ci-cd-broker-${var.env}"

  force_destroy = true
}

resource "aws_iam_user_group_membership" "ci-cd_broker" {
  user   = "${aws_iam_user.ci-cd_broker.name}"
  groups = ["ci-cd-broker"]
}

resource "aws_iam_access_key" "ci-cd_broker" {
  user = "${aws_iam_user.ci-cd_broker.name}"
}
