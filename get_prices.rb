#!/usr/bin/env ruby

require 'yaml'
require 'amazon-pricing'

broker_manifest_path = ARGV[0]

# load plans from file / stdin
# for each
#   find assoc plan in catalog based on unique_id
#   add to data structure the db_instance_class
#   look up the price for the class based on whether multi_az

def plans(manifest, plan, job, properties_key, service)
  manifest['instance_groups'].
    detect { |p| p['name'] == plan }.
    fetch('jobs').
    detect { |j| j['name'] == job }.
    fetch('properties').
    fetch(properties_key).
    fetch('catalog').
    fetch('services').
    detect { |s| s['name'] == service }.
    fetch('plans')
end

def calculate(prices, plans, manifest)
  plans(
    manifest,
    'rds_broker',
    'rds-broker',
    'rds-broker',
    'postgres'
  ).map { |plan|
    plan_id = plan['id']
    api_plan = plans.detect { |p| p['entity']['unique_id'] == plan_id }
    if api_plan.nil?
      raise "no api plan for id #{plan_id}:\n#{plan.to_yaml}"
    end
    db_instance_class = plan['rds_properties']['db_instance_class']
    rds_instance_type = prices.rds_instance_types.
      detect { |t| t.api_name == db_instance_class }
    is_multi_az = plan['rds_properties']['multi_az']
    price = rds_instance_type.price_per_hour(
      :postgresql,
      :ondemand,
      _term = nil,
      is_multi_az,
    )
    {
      name: plan['name'],
      multi_az: is_multi_az,
      instance_class: db_instance_class,
      plan_guid: plan_id,
      price_per_hour: price,
    }
  }
end

rds_price_list = Marshal.load(File.read('rds_price_list.dump'))
input_plans = YAML.safe_load($stdin)
broker_plans = YAML.load_file(broker_manifest_path)

puts calculate(rds_price_list.get_region('eu-west-1'), input_plans, broker_plans).to_yaml
