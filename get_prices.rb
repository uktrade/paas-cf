#!/usr/bin/env ruby

require 'yaml'

broker_manifest_path = ARGV[0]

# load plans from file / stdin
# for each
#   find assoc plan in catalog based on unique_id
#   add to data structure the db_instance_class
#   look up the price for the class based on whether multi_az

def plans(manifest, plan, job, properties_key, service)
  manifest['instance_groups'].
    detect { |p| p['name'] == plan }['jobs'].
    detect { |j| j['name'] == job }.
    fetch('properties')[properties_key]['catalog']['services'].
    detect { |s| s['name'] == service }.
    fetch('plans')
end

def calculate(plans, manifest)
  broker_plans = plans(
    manifest,
    'rds_broker',
    'rds-broker',
    'rds-broker',
    'postgres'
  )
  plans.map { |plan|
    plan_id = plan['entity']['unique_id']
    broker_plan = broker_plans.
      detect { |p| p['id'] == plan_id }

    raise "no broker plan for id #{plan_id}:\n#{plan.to_yaml}" if broker_plan.nil?

    {
      name: broker_plan['name'],
      plan_guid: plan_id,
      price_per_hour: 0,
    }
  }
end

input_plans = YAML.safe_load($stdin)
broker_plans = YAML.load_file(broker_manifest_path)

puts calculate(input_plans, broker_plans).to_yaml
