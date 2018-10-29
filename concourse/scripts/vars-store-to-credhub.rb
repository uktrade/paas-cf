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
      c['value'] = existing_secrets[c['name']]
      c['name'] = prefix + '/' + c['name']
      accum << c
    end
    accum
  }
}

puts result.to_yaml
