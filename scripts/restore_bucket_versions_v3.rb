# gem install aws-sdk
# gem install pg
require 'aws-sdk'
require 'pg'

Aws.config.update({
  region: 'eu-west-1',
})

def s3_object_delete_versions_older_than(bucket_name, timestamp)
  bucket = Aws::S3::Bucket.new(bucket_name)

  bucket.object_versions().each {|v|
    if v.last_modified > timestamp
      puts "Deleting s3://#{v.bucket_name}#{v.object_key} with version #{v.version_id}, dated #{v.last_modified}"
      v.delete
    end
  }
end

def get_lastest_modified_app_date(conn)
  conn.exec( "select updated_at from apps order by updated_at desc limit 1;" ) do |result|
    return Time.parse(result.first.values_at('updated_at').first + " UTC")
  end
end


def revert_objects_in_db(deploy_env)
  conn = PG.connect( host: 'localhost', port: 5432, dbname: 'api', user: 'api', password: ENV['CF_API_DB_PASSWORD'])

  latest_timestamp = get_lastest_modified_app_date(conn)
  s3_object_delete_versions_older_than("#{deploy_env}-cf-packages", timestamp)
  s3_object_delete_versions_older_than("#{deploy_env}-cf-droplets", timestamp)
end

revert_objects_in_db("hector");

