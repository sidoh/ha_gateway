require 'color'
require 'net/http'
require 'uri'
require 'mqtt'

require_relative '../../lib/mqtt_client_factory'

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
        send_request(command: 'set_white')
      else
        hue, sat, light = rgb.to_hsl.to_a
        request_params = {hue: hue * 360}

        if params['bulb_type'] == 'rgb_cct'
          sat *= (light < 0.5) ? light : (1 - light)
          val = light + sat
          sat = 2 * sat / (light + sat)

          request_params[:saturation] = sat * 100
        end

        send_request(request_params)
      end
    end

    def temperature(value)
      send_request(temperature: value)
    end

    def level(l)
      send_request(level: l)
    end

    def update_status(v)
      send_request(status: v)
    end

    private

    def endpoint
      "#{params['device_id']}/#{params['bulb_type'] || 'rgbw'}/#{params['group']}"
    end

    def send_request(request_params)
      if !params['transport'] || params['transport'] == 'http'
        send_http_request(request_params)
      elsif params['transport'] == 'mqtt'
        publish_mqtt_message(request_params)
      end
    end

    def publish_mqtt_message(request_params)
      mqtt_params = {}

      if params['username']
        mqtt_params.merge!({
          username: params['username'],
          password: params['password']
        })
      end

      if params['mqtt_port']
        mqtt_params.merge!({
          port: params['mqtt_port']
        })
      end

      client = MqttClientFactory.instance.get(params['broker'])
      client.publish(params['topic'], request_params.to_json)
    end

    def send_http_request(request_params)
      server = "http://#{params['host']}"
      uri = URI("#{server}/gateways/#{endpoint}")

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
