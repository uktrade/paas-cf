resource "datadog_timeboard" "uaa_usage" {
  title       = "${format("%s uaa login attempts", var.env)}"
  description = "Graphs of suspicious login activity"
  read_only   = true

  graph {
    title = "Failed login attempts"
    viz   = "timeseries"

    request {
      q = "${format("sum:cf.uaa.audit_service.user_authentication_failure_count{deployment:%s}", var.env)}"
    }
  }

  graph {
    title = "Failed password changes"
    viz   = "timeseries"

    request {
      q = "${format("sum:cf.uaa.audit_service.user_password_failures{deployment:%s}", var.env)}"
    }
  }

  graph {
    title = "Successful password changes"
    viz   = "timeseries"

    request {
      q = "${format("sum:cf.uaa.audit_service.user_password_changes{deployment:%s}", var.env)}"
    }
  }

  graph {
    title = "Attempts to login as user that does not exist"
    viz   = "timeseries"

    request {
      q = "${format("sum:cf.uaa.audit_service.user_not_found_count{deployment:%s}", var.env)}"
    }
  }
}

resource "datadog_monitor" "failed_logins" {
  name    = "${format("%s uaa - failed login attempts", var.env)}"
  type    = "metric alert"
  message = "${format("Anomalous levels of failed user authentication attempts detected. @govpaas-alerting-%s@digital.cabinet-office.gov.uk", var.aws_account)}"

  query = "${function("avg(last_30m):anomalies(sum:cf.uaa.audit_service.user_authentication_failure_count{deployment:%s}, 'agile', 2, direction='above') >= 1", var.env)}"

  locked = true

  thresholds {
    critical = "100.0"
  }

  tags {
    "deployment" = "${var.env}"
    "service"    = "${var.env}_monitors"
    "job"        = "uaa"
  }
}

resource "datadog_monitor" "failed_password_changes" {
  name    = "${format("%s uaa - failed password changes", var.env)}"
  type    = "metric alert"
  message = "${format("Anomalous levels of users failing to provide the correct password when changing their password. @govpaas-alerting-%s@digital.cabinet-office.gov.uk", var.aws_account)}"

  query = "${function("avg(last_30m):anomalies(sum:cf.uaa.audit_service.user_password_failures{deployment:%s}, 'agile', 2, direction='above') >= 1", var.env)}"

  locked = true

  thresholds {
    critical = "100.0"
  }

  tags {
    "deployment" = "${var.env}"
    "service"    = "${var.env}_monitors"
    "job"        = "uaa"
  }
}

resource "datadog_monitor" "user_not_found" {
  name    = "${format("%s uaa - users not found", var.env)}"
  type    = "metric alert"
  message = "${format("Anomalous levels of authentication attempts with a user name that does not exist. @govpaas-alerting-%s@digital.cabinet-office.gov.uk", var.aws_account)}"

  query = "${function("avg(last_30m):anomalies(sum:cf.uaa.audit_service.user_not_found_count{deployment:%s}, 'agile', 2, direction='above') >= 1", var.env)}"

  locked = true

  thresholds {
    critical = "100.0"
  }

  tags {
    "deployment" = "${var.env}"
    "service"    = "${var.env}_monitors"
    "job"        = "uaa"
  }
}
