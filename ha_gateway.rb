require 'sinatra'
require 'ledenet_api'
require 'color'
require 'openssl'

require_relative 'config_provider'

RGB_PARAMS = ['r', 'g', 'b']
config_provider = HaGateway::CachingConfigProvider.new(HaGateway::ConfigProvider.new)
api = LEDENET::Api.new(config_provider.ledenet_host)

before do
  timestamp = request.env['HTTP_X_SIGNATURE_TIMESTAMP']
  payload   = request.env['HTTP_X_SIGNATURE_PAYLOAD']
  signature = request.env['HTTP_X_SIGNATURE']

  digest = OpenSSL::Digest.new('sha1')
  data = (payload + timestamp)
  hmac = OpenSSL::HMAC.hexdigest(digest, config_provider.hmac_key, data)

  halt 403 unless hmac == signature
  halt 412 unless ((Time.now.to_i - 20) <= timestamp.to_i)
end

post '/leds' do
  puts params.inspect

  if params['status'] == 'on'
    api.on
  elsif params['status'] == 'off'
    api.off
  end

  if (RGB_PARAMS & params.keys) == RGB_PARAMS
    rgb = RGB_PARAMS.map { |x| params[x].to_i }
    api.update_color(*rgb)
  end

  status 200
  body '{"success": true}'
end
