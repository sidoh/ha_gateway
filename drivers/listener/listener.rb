require 'net/http'
require 'active_support/inflector'
require 'logger'
require 'json'

require_relative '../../helpers/http_helpers'
require_relative '../../lib/mqtt_client_factory'

module HaGateway
  class Listener
    include HttpHelpers

    attr_reader :params, :last_event_times

    def initialize(params = {})
      @params = params
      @last_event_times = {}
    end

    def fire_event(event, *args)
      event = event.to_s

      if dedup_threshold = params['dedup_threshold']
        now = current_timestamp

        if (last_time = last_event_times[event]) && (now <= (last_time + dedup_threshold))
          logger.debug "Skipping event #{event} in #{self.class} because last instance of event was too recently."
          return
        end

        last_event_times[event] = now
      end

      begin
        if event_config = params['events'][event]
          if http_config = event_config['http']
            http_event(http_config, *args)
          end

          if mqtt_config = event_config['mqtt']
            mqtt_event(mqtt_config, *args)
          end
        end
      rescue Exception => e
        logger.error "Caught exception when firing event: #{e}\n#{e.backtrace.join("\n")}"
      end
    end

    def logger
      @logger ||= Logger.new(STDOUT)
    end

    private

    def current_timestamp
      (Time.now.to_f*1000).to_i
    end

    def require_params(*p)
      p.each do |param|
        if ! params.include?(param.to_s)
          raise "Missing required parameter `param` for #{self.class}"
        end
      end
    end

    def mqtt_event(mqtt_config, *args)
      message = mqtt_config['message']

      if !message.is_a?(String)
        message = message.to_json
      end

      client = MqttClientFactory.instance.get(mqtt_config['broker'])
      client.publish(mqtt_config['topic'], message)
    end

    def http_event(http_config, *args)
      send_signed_http_request(
        http_config['method'],
        http_config['url'],
        http_config['params']
      )
    end
  end
end
