require 'color'
require 'net/http'
require 'uri'

module HaGateway
  class Esp8266MilightDriver
    attr_reader :params
    
    def initialize(params = {})
      @params = params
    end
    
    def on
      update_status('on')
    end
    
    def off
      update_status('off')
    end
    
    def on?
      raise "Milight doesn't support on?()."
    end
    
    def color(r, g, b)
      rgb = Color::RGB.new(r, g, b)
      
      if rgb.html == '#ffffff'
        send(command: 'set_white')
      else
        hsl = rgb.to_hsl
        send(hue: hsl.hue, level: hsl.lightness)
      end
    end
    
    def level(l)
      send(level: l)
    end
      
    def update_status(v)
      send(status: v)
    end
    
    private
    
    def send(request_params)
      server = "http://#{params['host']}"
      endpoint = "/gateways/#{params['device_id']}/#{params['group']}"
      uri = URI("#{server}#{endpoint}")
      
      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Put.new(uri)
        request['Content-Type'] = 'application/json'
        request.body = request_params.to_json
        request.basic_auth(params['username'], params['password'])
        
        response = http.request(request)
        
        if response.code.to_i != 200
          raise "Unexpected response from ESP8266 Milight API: #{response.inspect}"
        end
      end
    end
  end
end