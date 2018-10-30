#!/usr/bin/env ruby

require 'yaml'

if ARGV.length != 3
  abort <<-EOT
Usage:

   #{$0} <manifest.yml> <vars-store.yml> <new_secrets_prefix>

It creates a import.yml file to use with 'credhub import' with the
secret values from the given manifest and vars-store.yml

  EOT
end
pipelines = ARGV[0].split(",")

manifest = YAML.load_file(ARGV[0])
existing_secrets = YAML.load_file(ARGV[1])
prefix = ARGV[2]

result = {
  'credentials' => manifest['variables'].reduce([]) { |accum, c|
    if existing_secrets[c['name']]
      new_entry = {
        'name' => prefix + '/' + c['name'],
        'type' => c['type'],
        'value'=> existing_secrets[c['name']],
      }
      if c['options'] and c['options']['ca']
        new_entry['value'].delete('ca')
        new_entry['value']['ca_name'] = prefix + '/' + c['options']['ca']
      end
      new_entry['value'].delete('public_key_fingerprint')
      new_entry['value'].delete('password_hash')
      accum << new_entry
    end
    accum
  }
}

puts result.to_yaml
