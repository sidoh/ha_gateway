require 'ledenet_api'

module HaGateway
  module ConfigProvider
    @@config = nil

    def ledenet_host
      LEDENET.discover_devices.first.ip
    end

    def security_enabled?
      config_value(:require_hmac_signatures) == true
    end

    def config_value(k)
      config[k.to_s]
    end

    private
      def config
        if !@@config
          @@config = YAML.load_file('config/ha_gateway.yml')
        end
        @@config
      end
  end
end
