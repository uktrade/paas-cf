# gem install aws-sdk
# gem install pg
require 'aws-sdk'
require 'pg'

Aws.config.update({
  region: 'eu-west-1',
})

def s3_object_get_version_for_timestamp(bucket_name, prefix, timestamp)
  bucket = Aws::S3::Bucket.new(bucket_name)

  older_versions = bucket.object_versions(prefix: prefix).select {|v|
    v.last_modified < timestamp
  }.sort { |v1, v2|
    v1.last_modified <=> v2.last_modified
  }
  return older_versions.last
end

def s3_object_restore_version_for_timestamp(from_bucket_name, to_bucket_name, prefix, timestamp)
  old_version = s3_object_get_version_for_timestamp( from_bucket_name, prefix, timestamp)
  if old_version == nil
    puts "no old versions for #{prefix}"
  else
      puts "Restoring #{bucket_name}/#{prefix} to version #{old_version.version_id}..."
      bucket = Aws::S3::Bucket.new(to_bucket_name)
      object = bucket.object(prefix)
      object.copy_from(old_version)
  end
end

def get_all_app_guids(conn)
  guids = []
  conn.exec( "select guid from apps;" ) do |result|
    result.each do |row|
      guids << row.values_at('guid').first
    end
  end
  return guids
end


def get_all_droplet_guid_and_hashes(conn)
  guid_and_hashes = []
  conn.exec( "select guid, droplet_hash from apps where droplet_hash is not null;" ) do |result|
    result.each do |row|
      guid_and_hashes << {guid: row.values_at('guid').first, hash: row.values_at('droplet_hash').first}
    end
  end
  return guid_and_hashes
end

def get_lastest_modified_app_date(conn)
  conn.exec( "select updated_at from apps order by updated_at desc limit 1;" ) do |result|
    return Time.parse(result.first.values_at('updated_at').first + " UTC")
  end
end

def partitioned_key(key)
  key = key.to_s.downcase
  key = File.join(key[0..1], key[2..3], key)
  key
end

def revert_objects_in_db(deploy_env)
  conn = PG.connect( host: 'localhost', port: 5432, dbname: 'api', user: 'api', password: ENV['CF_API_DB_PASSWORD'])

  latest_timestamp = get_lastest_modified_app_date(conn)

  puts "Autodeteted lastest timestamp is #{latest_timestamp}"

  get_all_app_guids(conn).each { |guid|
    key = partitioned_key(guid)
    puts "processing package #{key}"
    s3_object_restore_version_for_timestamp(
      "#{deploy_env}-cf-packages-backup",
      "#{deploy_env}-cf-packages",
      key,
      latest_timestamp
    )
  }

  get_all_droplet_guid_and_hashes(conn).each { |guid_and_hash|
    key = partitioned_key(File.join(guid_and_hash[:guid], guid_and_hash[:hash]))
    puts "processing droplet #{key}"
    s3_object_restore_version_for_timestamp(
      "#{deploy_env}-cf-droplets-backup",
      "#{deploy_env}-cf-droplets",
      key,
      latest_timestamp
    )
  }
end

revert_objects_in_db("hector");

