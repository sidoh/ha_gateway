require_relative 'config_provider'

module HaGateway
  module DriverLoader
    include HaGateway::ConfigProvider

    def build_driver(type, key)
      devices = config_value(type)

      if devices.nil? or devices[key].nil?
        raise RuntimeError, "The #{type} \"#{key}\" is not defined. Add it to the config."
      end

      device = devices[key]
      driver = device['driver']

      begin
        require_relative "../drivers/#{type}/#{driver}"
      rescue LoadError => e
        raise RuntimeError, "Undefined driver type: #{type}/#{driver}"
      end

      Object.const_get("HaGateway::#{driver.capitalize}").new(params)
    end
  end
end
