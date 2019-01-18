yaml = YAML.safe_load(File.read("paas-cf/config/buildpacks.yml"))
yaml['buildpacks'].each do |bp|
  system("./paas-cf/concourse/scripts/upload-buildpack.sh", \
    bp['name'], bp['stack'].to_s, \
    bp['filename'].to_s, \
    bp['url'].to_s, \
    bp['sha'].to_s, out: $stdout, err: :out)
end
