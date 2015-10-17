require 'ledenet_api'

module HaGateway
  class ConfigProvider
    def hmac_key
      File.read('config/hmac.key')
    end

    def ledenet_host
      LEDENET.discover_devices.first.ip
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
