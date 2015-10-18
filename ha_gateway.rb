require 'sinatra'
require 'ledenet_api'
require 'bravtroller'
require 'color'
require 'openssl'

require_relative 'config_provider'

RGB_PARAMS = ['r', 'g', 'b']
config_provider = HaGateway::CachingConfigProvider.new(HaGateway::ConfigProvider.new)
ledenet_api = LEDENET::Api.new(config_provider.ledenet_host)
bravtroller = Bravtroller::Remote.new(Bravtroller::Client.new(config_provider.bravia_host))

before do
  if config_provider.security_enabled?
    timestamp = request.env['HTTP_X_SIGNATURE_TIMESTAMP']
    payload   = request.env['HTTP_X_SIGNATURE_PAYLOAD']
    signature = request.env['HTTP_X_SIGNATURE']

    halt 403 if payload.nil? or timestamp.nil? or signature.nil?

    digest = OpenSSL::Digest.new('sha1')
    data = (payload + timestamp)
    hmac = OpenSSL::HMAC.hexdigest(digest, config_provider.hmac_key, data)

    halt 403 unless hmac == signature
    halt 412 unless ((Time.now.to_i - 20) <= timestamp.to_i)
  end
end

post '/tv' do
  puts params.inspect

  if params['status'] == 'on'
    bravtroller.power_on(config_provider.bravia_hw_addr)
  elsif params['status'] == 'off'
    bravtroller.press_button('PowerOff')
  end
end

post '/leds' do
  puts params.inspect

  if params['status'] == 'on'
    ledenet_api.on
  elsif params['status'] == 'off'
    ledenet_api.off
  end

  if (RGB_PARAMS & params.keys) == RGB_PARAMS
    rgb = RGB_PARAMS.map { |x| params[x].to_i }
    ledenet_api.update_color(*rgb)
  end

  if params.include?('level')
    hsl_color = Color::RGB.new(*ledenet_api.current_color).to_hsl
    hsl_color.luminosity = params['level'].to_i

    adjusted_rgb = hsl_color.to_rgb.to_a.map { |x| (x * 255).to_i }

    ledenet_api.update_color(*adjusted_rgb)
  end

  status 200
  body '{"success": true}'
end
