resource "datadog_monitor" "gorouter-process" {
  name = "${data.null_data_source.datadog.inputs.env} gorouter process"
  type = "service check"
  message = "Missing gorouter processes in environment {{host.environment}}."
  escalation_message = "Missing router hosts! Check VM state."
  no_data_timeframe = "2"
  query = "'process.up'.over('environment:${data.null_data_source.datadog.inputs.env}','process:gorouter').by('host','process').last(6).count_by_status()"

  thresholds {
    ok = 0
    warning = 2
    critical = 10
  }

  require_full_window = true
  tags {
    "environment" = "${data.null_data_source.datadog.inputs.env}"
    "job" = "router"
  }
}
