resource "datadog_monitor" "pingdom" {
  name                = "${format("%s Pingdom checks", var.env)}"
  type                = "service check"
  message             = "One or more Pingdom checks are failing. Check Pingdom status."
  escalation_message  = "One or more Pingdom checks are still failing. Check Pingdom status."
  notify_no_data      = false
  require_full_window = true

  query = "${"'pingdom.status'.over('*').by('check','id').last(1).count_by_status()"}"

  thresholds {
    ok       = 1
    warning  = 2
    critical = 3
  }

  tags {
    "deployment" = "${var.env}"
    "service"    = "${var.env}_monitors"
  }
}
