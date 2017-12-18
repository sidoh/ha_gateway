require 'mqtt'

require_relative '../helpers/config_provider'

module HaGateway
  class MqttClientFactory
    include ConfigProvider

    def initialize
      mqtt_params = config_value(:mqtt_brokers)
      @clients = {}

      if mqtt_params
        mqtt_params.each do |name, params|
          name = name.to_s

          # Initialize within a thread to avoid disconnect errors getting tossed
          # into the main thread. There's probably a better way to deal with this.
          thread = Thread.new do |parent|
            begin
              @clients[name] = MQTT::Client.new(params)
              @clients[name].connect
            rescue Exception => e
              parent.raise(e)
            end
          end
        end
      end
    end

    def get(name)
      client = @clients[name.to_s]

      if client
        client.connect if !client.connected?
        client
      else
        raise "Unknown MQTT broker named: #{name}"
      end
    end

    @@instance = MqttClientFactory.new

    def self.instance
      @@instance
    end
  end
end
