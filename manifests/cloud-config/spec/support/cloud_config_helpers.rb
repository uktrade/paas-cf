require "open3"
require "singleton"
require "tempfile"
require "yaml"

module CloudConfigHelpers
  class Cache < ::Hash
    include Singleton
  end

  def cloud_config_with_defaults
    cloud_config_for_account("prod")
  end

  def cloud_config_for_account(account)
    sym = "cloud_config_for_#{account}".to_sym

    old_aws_account = ENV["AWS_ACCOUNT"]
    ENV["AWS_ACCOUNT"] = account
    Cache.instance[sym] ||= render_cloud_config
    ENV["AWS_ACCOUNT"] = old_aws_account

    Cache.instance[sym]
  end

private

  def root
    Pathname.new(File.expand_path("../../../..", __dir__))
  end

  def render_cloud_config
    workdir = Dir.mktmpdir("paas-cf-test")

    copy_terraform_fixtures("#{workdir}/terraform-outputs")

    env = {
      "PAAS_CF_DIR" => root.to_s,
      "WORKDIR" => workdir,
    }
    output, error, status = Open3.capture3(env, root.join("manifests/cloud-config/scripts/generate-cloud-config.sh").to_s)
    expect(status).to be_success, "generate-cloud-config.sh exited #{status.exitstatus}, stderr:\n#{error}"

    DeepFreeze.freeze(PropertyTree.load_yaml(output))
  ensure
    unless workdir.nil?
      FileUtils.rm_rf(workdir)
    end
  end
end

RSpec.configuration.include CloudConfigHelpers
