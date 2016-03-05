require 'ledenet_api'
require 'yaml'

module HaGateway
  class ConfigProvider
    def hmac_key
      load_config['hmac_secret']
    end

    def camera_hostname
      load_config['camera_hostname']
    end

    def camera_username
      load_config['camera_username']
    end

    def camera_password
      load_config['camera_password']
    end

    def ledenet_host
      LEDENET.discover_devices.first.ip
    end

    def bravia_host
      load_config['bravia_host']
    end

    def bravia_hw_addr
      load_config['bravia_hw_addr']
    end

    def security_enabled?
      load_config['require_hmac_signatures'] == true
    end

    private
      def load_config
        YAML.load_file('config/ha_gateway.yml')
      end
  end

  class CachingConfigProvider
    def initialize(delegate)
      @delegate = delegate
      @cache = {}
    end

    def method_missing(m, *args, &block)
      if @cache[m].nil?
        @cache[m] = @delegate.send(m, *args, &block)
      end

      @cache[m]
    end
  end
end
