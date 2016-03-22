require_relative 'config_provider'
require_relative '../drivers/composite_driver'

module HaGateway
  module DriverLoader
    include HaGateway::ConfigProvider

    @@drivers = {}

    def build_driver(type, key)
      dk = driver_key(type, key)
      if !@@drivers[dk].nil?
        return @@drivers[dk]
      end

      devices = config_value(type)

      if devices.nil? or devices[key].nil?
        raise RuntimeError, "The #{type} \"#{key}\" is not defined. Add it to the config."
      end

      device = devices[key]
      driver = device['driver']

      driver_instance = if driver == 'composite'
        composite_devices = device['params']['components'].map { |c| build_driver(type, c) }
        CompositeDriver.new(type, *composite_devices)
      else
        begin
          require_relative "../drivers/#{type}/#{driver}"
        rescue LoadError => e
          raise RuntimeError, "Undefined driver type: #{type}/#{driver}"
        end

        Object.const_get("HaGateway::#{camel_case(driver)}Driver").new(device['params'])
      end

      @@drivers[driver_key(type, key)] = driver_instance
    end

    def driver_key(type, key)
      "#{type}/#{key}"
    end

    private
      def camel_case(s)
        return s if s !~ /_/ && s =~ /[A-Z]+.*/
        s.split('_').map{|e| e.capitalize}.join
      end
  end
end
