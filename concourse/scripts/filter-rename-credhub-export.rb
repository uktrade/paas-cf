#!/usr/bin/env ruby

require 'yaml'

if ARGV.length < 2
  abort <<-EOT
Usage:

   #{$0} <old_prefix:new_prefix> [<secret_name_selector>...]

It filters the output of a `credhub export` and:

  - changes the prefix in the name
  - secret_name_selector: List of names to cherry pick for the name

The new export file can be imported back by `credhub import`

Example:

  ./#{$0}  '/bosh/cf/:/concourse/main/' \
      bosh/cf/secret1 \
      bosh/cf/secret2 \
      bosh/cf/secret3
  EOT
end


old_prefix, new_prefix = ARGV.shift.split(':')
selectors = ARGV

import = YAML.safe_load(STDIN)

result = {
  'credentials' => import['credentials'].reduce([]) { |accum, c|
    if selectors.empty? or selectors.include?(c['name'])
      c['name'] = c['name'].gsub(Regexp.new("^"+old_prefix), new_prefix)
      accum << c
    end
    accum
  }
}

puts result.to_yaml

