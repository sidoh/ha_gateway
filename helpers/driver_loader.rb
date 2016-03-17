require_relative 'config_provider'

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

      begin
        require_relative "../drivers/#{type}/#{driver}"
      rescue LoadError => e
        raise RuntimeError, "Undefined driver type: #{type}/#{driver}"
      end

      @@drivers[driver_key(type, key)] = Object.const_get("HaGateway::#{camel_case(driver)}Driver").new(device['params'])
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
