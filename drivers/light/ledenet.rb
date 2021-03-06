require 'color'
require 'ledenet_api'

require_relative 'light'

module HaGateway
  class LedenetDriver < Light
    attr_reader :params

    def initialize(params = {})
      @params = params
    end

    def on
      api.on
    end

    def off
      api.off
    end

    def on?
      api.on?
    end

    def color(r, g, b)
      api.update_rgb(r, g, b)
    end

    def level(l)
      hsl_color = Color::RGB.new(*api.current_rgb).to_hsl
      hsl_color.luminosity = l.to_i

      adjusted_rgb = hsl_color.to_rgb.to_a.map { |x| (x * 255).to_i }

      api.update_rgb(*adjusted_rgb)
      api.update_warm_white((l * (255/100)).to_i)
    end

    private
      def build_api
        if params['host']
          LEDENET::Api.new(params['host'])
        elsif params['hw_addr']
          normalized_addr = params['hw_addr'].gsub(':', '').upcase
          device = LEDENET.discover_devices.
            reject { |x| x.hw_addr != normalized_addr }.
            first

          if device.nil?
            raise RuntimeError, "Unable to find LEDENET device with hw addr: #{params['hw_addr']}"
          end

          LEDENET::Api.new(device.ip)
        else
          device = LEDENET.discover_devices.first

          if device.nil?
            raise RuntimeError, "Unable to find any LEDENET devices"
          end

          LEDENET::Api.new(device.ip)
        end
      end
  end
end
