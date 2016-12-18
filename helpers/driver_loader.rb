require 'active_support/inflector'

require_relative 'config_provider'

require_relative '../drivers/composite_driver'
require_relative '../drivers/noop_driver'
require_relative '../drivers/demux_driver'

module HaGateway
  module DriverLoader
    include HaGateway::ConfigProvider

    @@drivers = {}
    
    def get_devices(type)
      config_value(type.pluralize) || {}
    end

    def build_driver(type, key)
      dk = driver_key(type, key)
      if !@@drivers[dk].nil?
        return @@drivers[dk]
      end

      if !(device = get_devices(type)[key])
        raise RuntimeError, "The #{type} \"#{key}\" is not defined. Add it to the config."
      end
      
      build_driver_from_defn(type, key, device)
    end

    def build_driver_from_defn(type, key, device)
      driver = device['driver']

      driver_instance = if driver == 'composite'
        composite_devices = device['params']['components'].map { |c| build_driver(type, c) }
        CompositeDriver.new(type, device['params'], *composite_devices)
      elsif driver == 'demux'
        demux_mapping = device['params']['delegates'].map { |action, defn|
          [action, build_driver_from_defn(type, "__#{key}__#{action}", defn)]
        }
        demux_mapping = Hash[demux_mapping]

        DemuxDriver.new(type, device['params'], demux_mapping)
      elsif driver == 'noop'
        NoOpDriver.new
      else
        begin
          require_relative "../drivers/#{type}/#{driver}"
        rescue LoadError => e
          raise RuntimeError, "Undefined driver type: #{type}/#{driver}:#{e.backtrace}"
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
