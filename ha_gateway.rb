require 'sinatra'
require 'sinatra/json'

require 'ledenet_api'
require 'bravtroller'
require 'color'
require 'openssl'
require 'net/ping'

require 'open-uri'

require_relative 'config_provider'

RGB_PARAMS = ['r', 'g', 'b']
config_provider = HaGateway::CachingConfigProvider.new(HaGateway::ConfigProvider.new)
ledenet_api = LEDENET::Api.new(config_provider.ledenet_host)

def camera_url(host, params)
  "http://#{host}/cgi-bin/CGIProxy.fcgi?#{URI.encode_www_form(params)}"
end

before do
  if config_provider.security_enabled?
    timestamp = request.env['HTTP_X_SIGNATURE_TIMESTAMP']
    payload   = request.env['HTTP_X_SIGNATURE_PAYLOAD']
    signature = request.env['HTTP_X_SIGNATURE']

    if [payload, timestamp, signature].any?(&:nil?)
      logger.info "Access denied: incomplete signature params."
      logger.info "timestamp = #{timestamp}, payload = #{payload}, signature = #{signature}"
      halt 403
    end

    digest = OpenSSL::Digest.new('sha1')
    data = (payload + timestamp)
    hmac = OpenSSL::HMAC.hexdigest(digest, config_provider.hmac_key, data)

    if hmac != signature
      logger.info "Access denied: incorrect signature. Computed = '#{hmac}', provided = '#{signature}'"
      halt 403
    end

    if ((Time.now.to_i - 20) > timestamp.to_i)
      logger.info "Invalid parameter. Timestamp expired: #{timestamp}"
      halt 412
    end
  end
end

get '/camera' do
  def download(url, path)
    File.open(path, "w") do |f|
      IO.copy_stream(open(url), f)
    end
  end

  params = {
    usr: config_provider.camera_username,
    pwd: config_provider.camera_password,
    cmd: 'snapPicture2'
  }
  url = camera_url(config_provider.camera_hostname, params)

  content_type 'image/jpeg'
  open(url) { |f| f.read }
end

post '/camera/recording' do
  camera_params = {
    usr: config_provider.camera_username,
    pwd: config_provider.camera_password,
    cmd: 'setScheduleRecordConfig',
    isEnable: 1,
    recordLevel: 4,
    spaceFullMode: 0,
    isEnableAudio: 0
  }

  # The schedule is configured by 7 vars, one for each day of the week. The value
  # for each var is a bitmask of length 48, with each bit representing a 30
  # minute window. If, for example, the most significant bit is set to 1, then
  # scheduled recording for that day is enabled from 00:00:00 -- 00:29:59.
  value = params['enabled'] == 'true' ? (2**48 - 1) : 0
  (0..6).each { |i| camera_params["schedule#{i}"] = value }

  open(camera_url(config_provider.camera_hostname, camera_params))
end

get '/tv' do
  ping = Net::Ping::External.new(config_provider.bravia_host)
  tv_status = ping.ping? ? 'on' : 'off'

  status 200
  json status: tv_status
end

post '/tv' do
  bravtroller = Bravtroller::Remote.new(Bravtroller::Client.new(config_provider.bravia_host))

  if params['status'] == 'on'
    bravtroller.power_on(config_provider.bravia_hw_addr)
  elsif params['status'] == 'off'
    bravtroller.press_button('PowerOff')
  end
end

post '/leds' do
  logger.info params.inspect

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
