require 'ledenet_api'

module HaGateway
  module ConfigProvider
    def ledenet_host
      LEDENET.discover_devices.first.ip
    end

    def security_enabled?
      require_hmac_signatures == true
    end

    def method_missing(m)
      v = config[m]
      raise RuntimeError "Undefined config key: #{k}" unless v
      v
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
