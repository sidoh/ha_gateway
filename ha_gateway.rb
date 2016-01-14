require 'sinatra'
require 'ledenet_api'
require 'openssl'

require_relative 'config_provider'
config_provider = HaGateway::CachingConfigProvider.new(HaGateway::ConfigProvider.new)

before do
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

post '/leds' do
  puts params.inspect

  api = LEDENET::Api.new(params['ip'])
    # Set Power Status
    if params['status'] == 'on' || params['switch'] == 'on'
      api.on
    elsif params['status'] == 'off' || params['switch'] == 'off'
      api.off
    end

    r,g,b,w,powerState = api.current_status
    h,s,l = rgbToHsv(r,g,b)

    # Is the device a Magic UFO?
    if params['deviceType'].casecmp("UFO").zero?
      # Adjust HSL only
      if params.include?('hue') && params.include?('saturation') && params.include?('level')
        r,g,b = hsvToRgb((params['hue'].to_f*3.6),params['saturation'].to_f,params['level'].to_f)
        api.update_ufo(r,g,b,w, false)
      end
      # Adjust level only
      if params.include?('level') && !params.include?('hue') && !params.include?('saturation') 
        h,s,l = rgbToHsv(r,g,b)
        r,g,b = hsvToRgb(h,s,(params['level'].to_i))
        api.update_ufo(r,g,b,w, false) 
      end
      # Adjust saturation only
      if params.include?('saturation') && !params.include?('hue') && !params.include?('level') 
        h,s,v = rgbToHsv(r,g,b)
        r,g,b = hsvToRgb(h,params['saturation'].to_f,v)
        api.update_ufo(r,g,b,w, false)
      end
      # Adjust hue only
      if params.include?('hue') && !params.include?('saturation') && !params.include?('level') 
        h,s,v = rgbToHsv(r,g,b)
        r,g,b = hsvToRgb(params['hue'].to_f,s,v)
        api.update_ufo(r,g,b,w, false)
      end
      # Adjust Warm White only
      if params.include?('UFOWWLevel') && !params.include?('saturation') && !params.include?('level') && !params.include?('hue')
        api.update_ufo(r,g,b,params['UFOWWLevel'].to_i*2.55, false)
      
      end
    else # Adjust a bulb
      # Adjust HSL
      if params.include?('hue') && params.include?('saturation') && params.include?('level')
        # If H & S from ST are the WW button's level, enable WW
        if params['hue'] == "16.66666666666666" && params['saturation'] == "27.45097875595093"
          w = params['level'].to_i*2.55 # Convert from 0-100 to 0-255
          api.update_bulb_white(w,false)
        else
          r,g,b = hsvToRgb(params['hue'].to_f*3.6, params['saturation'].to_f, params['level'].to_f)
          api.update_bulb_color(r,g,b, false)
        end
      end
      # Adjust level only
      if params.include?('level') && !params.include?('hue') && !params.include?('saturation') 
        # If colors are off, adjust WW
        if [r,g,b] == [0,0,0]
          w = params['level'].to_i*2.55 #Convert from 0-100 to 0-255
          api.update_bulb_white(w,false)
        else
          h,s,v = rgbToHsv(r,g,b)
          r,g,b = hsvToRgb(h,s,params['level'].to_i*2.55)
          api.update_bulb_color(r,g,b, false)
        end
      end
      # Adjust saturation only
      if params.include?('saturation') && !params.include?('hue') && !params.include?('level') 
        # Get the bulb's hue and level, if in WW mode
        if [r,g,b] == [0,0,0] && w > 0
          r,g,b = hsvToRgb(60.0,27.45097875595093,w/2.55)
        end
        h,s,v = rgbToHsv(r,g,b)
        r,g,b = hsvToRgb(h,params['saturation'].to_f,v)
        api.update_bulb_color(r,g,b, false)
      end
      # Adjust hue only
      if params.include?('hue') && !params.include?('saturation') && !params.include?('level') 
        # Get the bulb's hue and level, if in WW mode
        if [r,g,b] == [0,0,0] && w > 0
          r,g,b = hsvToRgb(60.0,27.45097875595093,w/2.55)
        end
        h,s,v = rgbToHsv(r,g,b)
        r,g,b = hsvToRgb(params['hue'].to_f,s,v)
        api.update_bulb_color(r,g,b, false)
      end
    end

    r,g,b,w,powerState = api.current_status # Get new settings from the device
    h,s,l = rgbToHsv(r,g,b)

    if !params['deviceType'].casecmp("UFO").zero? # If the device isn't a UFO, set the RGB to what WW's H & S are
      if [r,g,b] == [0,0,0] && w > 0
        r,g,b = hsvToRgb(16.66666666666666, 27.45097875595093, (w/2.55))
      end
      status 200
      headers \
        "powerState" => powerState,
        "level" => l.to_s,
        "hex" => "#" + to_hex(r) + to_hex(g) + to_hex(b)

    else # If the device is a UFO, change the other parameters.
      status 200
      headers \
        "powerState" => powerState,
        "level" => l.to_s,
        "hex" =>  "#" + to_hex(r) + to_hex(g) + to_hex(b),
        "UFOWWLevel" => (w/2.55).to_s
    end
    status 200
    body '{"success": true}'
end
def rgbToHsv(r, g, b)
  # Takes an RGB value (0-255) and returns HSV in 0-360, 0-100, 0-100
  r /= 255.0
  g /= 255.0
  b /= 255.0

  max = [r, g, b].max.to_f
  min = [r, g, b].min.to_f
  delta = (max - min).to_f
  v = (max * 100.0).to_f

  max != 0.0 ? s = delta / max * 100.0 : s=0
  
  if (s == 0.0) 
    h = 0.0
  else
      if (r == max)
        h = ((g - b) / delta).to_f
      elsif (g == max)
        h = (2 + (b - r) / delta).to_f
      elsif (b == max)
        h = (4 + (r - g) / delta).to_f
    end
    h *= 60.0
    h += 360 if (h < 0)
  end
  return h,s,v
end
def hsvToRgb(h,s,v)
  h /= 360.0
  s /= 100.0
  v /= 100.0

  if s == 0.0
     r = v * 255
     g = v * 255
     b = v * 255
  else
    h = (h * 6).to_f
    h = 0 if h == 6
    i = h.floor
    var_1 = (v * ( 1.0 - s )).to_f
    var_2 = (v * ( 1.0 - s * ( h - i ) )).to_f
    var_3 = (v * ( 1.0 - s * ( 1.0 - ( h - i )))).to_f
  end

  if i == 0 
    r = v
    g = var_3
    b = var_1
  elsif i == 1
    r = var_2
    g = v
    b = var_1
  elsif i == 2
    r = var_1
    g = v
    b = var_3
  elsif i == 3
    r = var_1
    g = var_2
    b = v
  elsif i == 4
    r = var_3
    g = var_1
    b = v
  else
    r = v
    g = var_1
    b = var_2
  end

    if r==nil
      r=0
    end
    if g==nil
      g=0
    end
    if b==nil
      b=0
    end

    r *= 255
    g *= 255
    b *= 255

  return r.to_i, g.to_i, b.to_i
end
def to_hex(number)
  number.to_s(16).upcase.rjust(2, '0')
end
