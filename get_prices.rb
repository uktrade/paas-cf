#!/usr/bin/env ruby

require 'yaml'
require 'amazon-pricing'

broker_manifest_path = ARGV[0]

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

def paas_db_to_aws_db
  {
    'postgres' => :postgresql,
    'mysql' => :mysql,
  }
end

def storage_cost_in_gb_month
  {
    postgresql: {
      true => 0.253,
      false => 0.127,
    },
    mysql: {
      true => 0.253,
      false => 0.127,
    }
  }
end

def calculate_for_db(db_name, prices, plans, manifest)
  plans(
    manifest,
    'rds_broker',
    'rds-broker',
    'rds-broker',
    db_name,
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
      paas_db_to_aws_db[db_name],
      :ondemand,
      _term = nil,
      is_multi_az,
    )
    storage_cost = storage_cost_in_gb_month[paas_db_to_aws_db[db_name]][is_multi_az]
    {
      name: plan['name'],
      multi_az: is_multi_az,
      instance_class: db_instance_class,
      plan_guid: plan_id,
      allocated_storage: plan['rds_properties']['allocated_storage'],
      price_per_hour: price,
      compute_formula: "ceil($time_in_seconds/3600) * #{price}",
      storage_formula: "($storage_in_mb/1024) * ceil($time_in_seconds/2678401) * #{storage_cost}",
    }
  }
end

def calculate(prices, plans, manifest)
  {
    postgres: calculate_for_db('postgres', prices, plans, manifest),
    mysql: calculate_for_db('mysql', prices, plans, manifest),
  }
end

rds_price_list = Marshal.load(File.read('rds_price_list.dump'))
input_plans = YAML.safe_load($stdin)
broker_plans = YAML.load_file(broker_manifest_path)

puts calculate(rds_price_list.get_region('eu-west-1'), input_plans, broker_plans).to_yaml
