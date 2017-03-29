require 'net/https'
require 'uri'
require 'json'

url = URI('https://api.pagerduty.com/incidents?statuses[]=triggered&statuses[]=acknowledged')
http = Net::HTTP.new(url.host, url.port)
http.use_ssl = true

api_key = ENV['PAGERDUTY_APIKEY']

SCHEDULER.every '30s' do
  triggered = 0
  acknowledged = 0

  request = Net::HTTP::Get.new(url)
  request['Accept'] = 'application/vnd.pagerduty+json;version=2'
  request['Authorization'] = "Token token=#{api_key}"

  response = http.request(request)
  json = JSON.parse(response.body)

  json['incidents'].each do |incident|
    triggered += 1 if incident['status'] == 'triggered'
    acknowledged += 1 if incident['status'] == 'acknowledged'
  end

  send_event(
      'pagerduty_counts',
      criticals: triggered,
      warnings: acknowledged,
      unknowns: 0
  )
end
