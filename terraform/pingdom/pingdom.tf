variable "pingdom_user" {}

variable "pingdom_password" {}

variable "pingdom_api_key" {}

variable "pingdom_account_email" {}

variable "apps_dns_zone_name" {}

variable "env" {}

variable "pingdom_contact_ids" {
  type = "list"
}

provider "pingdom" {
  user          = "${var.pingdom_user}"
  password      = "${var.pingdom_password}"
  api_key       = "${var.pingdom_api_key}"
  account_email = "${var.pingdom_account_email}"
}

resource "pingdom_check" "paas_http_healthcheck" {
  type                     = "http"
  name                     = "PaaS HTTPS - ${var.env}"
  host                     = "healthcheck.${var.apps_dns_zone_name}"
  url                      = "/"
  shouldcontain            = "END OF THIS PROJECT GUTENBERG EBOOK"
  encryption               = true
  resolution               = 1
  uselegacynotifications   = true
  sendtoemail              = true
  sendnotificationwhendown = 2
  notifywhenbackup         = true
  contactids               = ["${var.pingdom_contact_ids}"]
}

resource "pingdom_check" "paas_postgres_healthcheck" {
  type                     = "http"
  name                     = "PaaS Postgres DB - ${var.env}"
  host                     = "healthcheck.${var.apps_dns_zone_name}"
  url                      = "/db?service=postgres"
  shouldcontain            = "\"success\": true"
  encryption               = true
  resolution               = 1
  uselegacynotifications   = true
  sendtoemail              = true
  sendnotificationwhendown = 2
  notifywhenbackup         = true
  contactids               = ["${var.pingdom_contact_ids}"]
}

resource "pingdom_check" "paas_mysql_healthcheck" {
  type                     = "http"
  name                     = "PaaS MySQL DB - ${var.env}"
  host                     = "healthcheck.${var.apps_dns_zone_name}"
  url                      = "/db?service=mysql"
  shouldcontain            = "\"success\": true"
  encryption               = true
  resolution               = 1
  uselegacynotifications   = true
  sendtoemail              = true
  sendnotificationwhendown = 2
  notifywhenbackup         = true
  contactids               = ["${var.pingdom_contact_ids}"]
}
