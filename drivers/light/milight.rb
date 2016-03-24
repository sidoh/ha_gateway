require 'limitless_led'

require_relative 'light'
require_relative '../repeat_wrapper'

module HaGateway
  class MilightDriver < Light
    attr_reader :driver_params

    def initialize(driver_params = {})
      @driver_params = driver_params
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
      color = Color::RGB.new(r, g, b)

      if color == Color::RGB::White
        api.white
      else
        api.color(color)
      end
    end

    def level(l)
      normalized_value = (l * (27.0/100)).round
      normalized_value = [2, normalized_value].max
      normalized_value = [27, normalized_value].min

      api.brightness(normalized_value)
    end

    private
      def build_api
        if !driver_params['host']
          raise RuntimeError, "Must specify \"host\" parameter for Milight driver (#{driver_params.inspect})."
        elsif !driver_params['group']
          raise RuntimeError, "Must specify \"group\" parameter for Milight driver."
        end

        api = LimitlessLed::Bridge.new(host: driver_params['host']).group(driver_params['group'].to_i)

        if driver_params['repeat_packets']
          api = HaGateway::RepeatWrapper.new(api, driver_params['repeat_packets'].to_i)
        end

        api
      end
  end
end
