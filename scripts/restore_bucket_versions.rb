# gem install aws-sdk
# gem install pg
require 'aws-sdk-core'
require 'pg'

deploy_env="hector"

Aws.config.update({
  region: 'eu-west-1',
})

s3client = Aws::S3.new


def s3_object_get_version_for_timestamp(s3client, bucket_name, prefix, timestamp)
  response = s3client.list_object_versions(bucket: bucket_name, prefix: prefix)

  older_versions = response.versions.select {|v|
    v.last_modified < timestamp
  }
  older_versions.sort { |v1, v2| v1.last_modified <=> v2.last_modified }
  return older_versions.first
end

def s3_object_restore_version_for_timestamp(s3client, bucket_name, prefix, timestamp)
  old_version = s3_object_get_version_for_timestamp(s3client, bucket_name, prefix, timestamp)
  puts old_version
  if not old_version.is_latest
    s3client.get_object(bucket: bucket_name, key: prefix).copy_from(prefix, version_id: old_version.id)
  end
end

bucket_name = "hector-state"
prefix = "test"

#bucket_name = "hector-cf-packages"
#prefix = "2a/18/2a18b47f-13a6-461e-8255-c5301d93c5e7"
#t = Time.now - (3600 * 24 * 6 )
#get_version_for_timestamp(bucket_name, prefix, t)



# Output a table of current connections to the DB
conn = PG.connect( host: 'localhost', port: 5432, dbname: 'api', user: 'api', password: ENV['CF_API_DB_PASSWORD'])

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
    return Time.parse(result.first.values_at('updated_at').first)
  end
end

def partitioned_key(key)
  key = key.to_s.downcase
  key = File.join(key[0..1], key[2..3], key)
  key
end


latest_timestamp = get_lastest_modified_app_date(conn)
get_all_app_guids(conn).each { |guid|
  puts s3_object_get_version_for_timestamp("#{deploy_env}-cf-packages", partitioned_key(guid), latest_timestamp)
}

get_all_droplet_guid_and_hashes(conn).each { |guid_and_hash|
  puts s3_object_get_version_for_timestamp(
    "#{deploy_env}-cf-droplets",
    partitioned_key(File.join(guid_and_hash[:guid], guid_and_hash[:hash])),
    latest_timestamp
  )
}

