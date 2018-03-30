#!/usr/bin/env ruby

require 'json'
require 'yaml'
require 'amazon-pricing'
require 'hashie'

broker_manifest_path = ARGV[0]

def plans(manifest, service)
  manifest.extend Hashie::Extensions::DeepFind
  manifest
    .deep_select('plans')
    .flatten.select { |p| p['rds_properties']['engine'] == service }
end

def paas_db_to_aws_db
  {
    'postgres' => :postgresql,
    'mysql' => :mysql
  }
end

def storage_cost_in_gb_month
  {
    postgresql: {
      true => 0.253,
      false => 0.127
    },
    mysql: {
      true => 0.253,
      false => 0.127
    }
  }
end

def calculate_for_db(db_name, prices, plans, manifest)
  plans(manifest, db_name).map do |plan|
    plan_id = plan['id']
    api_plan = plans.detect { |p| p['entity']['unique_id'] == plan_id }
    raise "no api plan for id #{plan_id}:\n#{plan.to_yaml}" if api_plan.nil?
    db_instance_class = plan['rds_properties']['db_instance_class']
    rds_instance_type = prices.rds_instance_types
                              .detect { |t| t.api_name == db_instance_class }
    is_multi_az = plan['rds_properties']['multi_az']
    price = rds_instance_type.price_per_hour(
      paas_db_to_aws_db[db_name],
      :ondemand,
      _term = nil,
      is_multi_az
    )
    storage_cost = storage_cost_in_gb_month[paas_db_to_aws_db[db_name]][is_multi_az]
    {
      name: "#{db_name} #{plan['name']}",
      multi_az: is_multi_az,
      instance_class: db_instance_class,
      plan_guid: plan_id,
      storage_in_mb: plan['rds_properties']['allocated_storage'] * 1024,
      memory_in_mb: 0,
      components: [{
        name: 'instance',
        formula: "ceil($time_in_seconds/3600) * #{price}",
        currency_code: "USD",
        vat_code: "Standard"
      }, {
        name: 'storage',
        formula: "($storage_in_mb/1024) * ceil($time_in_seconds/2678401) * #{storage_cost}"
        currency_code: "USD",
        vat_code: "Standard"
      }]
    }
  end
end

def calculate(prices, plans, manifest)
  {
    postgres: calculate_for_db('postgres', prices, plans, manifest),
    mysql: calculate_for_db('mysql', prices, plans, manifest)
  }
end

rds_price_list = Marshal.load(File.read('rds_price_list.dump'))
input_plans = YAML.safe_load($stdin)
broker_plans = YAML.load_file(broker_manifest_path)

puts JSON.pretty_generate(calculate(rds_price_list.get_region('eu-west-1'), input_plans, broker_plans))
