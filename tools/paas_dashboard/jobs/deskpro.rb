require 'net/https'
require 'uri'
require 'json'

url = URI('https://support.deskpro.com:443/api/tickets?status[]=awaiting_user&status[]=awaiting_agent')
http = Net::HTTP.new(url.host, url.port)
http.use_ssl = true

user = ENV['DESKPRO_USER']
pass = ENV['DESKPRO_PASS']

SCHEDULER.every '5s' do
  request = Net::HTTP::Get.new(url)
  request['Accept'] = 'application/json'
  request.basic_auth user, pass

  response = http.request(request)
  json = JSON.parse(response.body)

  p json

  send_event(
      'deskpro_counts',
      criticals: 0,
      warnings: 0,
      unknowns: 0
  )
end
