#!/usr/bin/env ruby

api_key = ENV['TF_VAR_datadog_api_key']
app_key = ENV['TF_VAR_datadog_app_key']
dog = Dogapi::Client.new(api_key, app_key)
