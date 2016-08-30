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

def clean_latest_delete_mark_and_get_object(bucket_name, prefix)
  bucket = Aws::S3::Bucket.new(bucket_name)
  latest_version = bucket.object_versions(prefix: prefix).find {|v|
    v.is_latest
  }
  begin
    latest_version.head
  rescue Aws::S3::Errors::Http405Error
    puts "Deleting latest object delete mark"
    latest_version.delete
  end
end

def s3_object_restore_version_for_timestamp(bucket_name, prefix, timestamp)
  old_version = s3_object_get_version_for_timestamp( bucket_name, prefix, timestamp)
  if old_version == nil
    puts "no old versions for #{prefix}"
  else
    if not old_version.is_latest
      puts "Restoring #{bucket_name}/#{prefix} to version #{old_version.version_id}..."
      bucket = Aws::S3::Bucket.new(bucket_name)

      clean_latest_delete_mark_and_get_object(bucket_name, prefix)
      object = bucket.object(prefix)
      if old_version.etag != object.etag
        # http://docs.aws.amazon.com/AmazonS3/latest/dev/DeleteMarker.html

        object.copy_from(old_version)
        puts "OK"
      else
        puts "Last version has same etag than version to restore, skipping"
      end
    else
      puts "Already latest version"
    end
  end
end

def s3_object_delete_versions_older_than(bucket_name, timestamp)
  bucket = Aws::S3::Bucket.new(bucket_name)

  bucket.object_versions().each {|v|
    if v.last_modified > timestamp
      puts "Deleting s3://#{v.bucket_name}#{v.object_key} with version #{v.version_id}, dated #{v.last_modified}"
      v.delete
    end
  }
end

bucket_name="hector-state"
timestamp=Time.now -100
s3_object_delete_versions_older_than(bucket_name, timestamp)

#bucket_name = "hector-state"
#prefix = "test"

#bucket_name = "hector-cf-packages"
#prefix = "2a/18/2a18b47f-13a6-461e-8255-c5301d93c5e7"
#t = Time.now - (3600 * 24 * 6 )
#get_version_for_timestamp(bucket_name, prefix, t)



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
    s3_object_restore_version_for_timestamp("#{deploy_env}-cf-packages", key, latest_timestamp)
  }

  get_all_droplet_guid_and_hashes(conn).each { |guid_and_hash|
    key = partitioned_key(File.join(guid_and_hash[:guid], guid_and_hash[:hash]))
    puts "processing droplet #{key}"
    s3_object_restore_version_for_timestamp(
      "#{deploy_env}-cf-droplets",
      key,
      latest_timestamp
    )
  }
end

revert_objects_in_db("hector");

