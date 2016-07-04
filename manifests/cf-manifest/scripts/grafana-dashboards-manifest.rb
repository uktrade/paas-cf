#!/usr/bin/env ruby

require 'yaml'
require 'json'

dashboards_dir=ARGV[0]
dashboard_files=Dir[dashboards_dir + '/*.json']
dashboards_hash = { 'properties' => { 'grafana' => 'dashboards' } }

dashboard_files.each{ |dashboard_file|
  json = File.read(dashboard_file)
  dashboards_hash['properties']['grafana']['dashboards'] = JSON.load(json)
}

YAML.dump(dashboards_hash, "grafana-dasbboards-manifest.yml")
