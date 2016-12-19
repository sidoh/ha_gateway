require 'net/http'
require 'active_support/inflector'
require 'logger'
require 'json'

require_relative '../../helpers/config_provider'
require_relative '../../helpers/security'

module HaGateway
  class Listener
    attr_reader :params, :last_event_times
    
    include ConfigProvider
    include Security
    
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
    
    def http_event(http_config, *args)
      url = http_config['url']
      
      if !url.start_with?('http')
        url = "#{config_value('site_location')}#{url}"
      end
      
      uri = URI(url)
      
      Net::HTTP.start(uri.host, uri.port) do |http|
        method = http_config['method'].titleize
        request = Net::HTTP.const_get(method).new(uri)
        
        body = ''
        
        if params = http_config['params']
          body = params.to_json
          request.body = body
          request.content_type = 'application/json'
        end
        
        params ||= {}
        hmac_headers(request.path, body).each do |header, value|
          request[header] = value
        end
        
        http.request(request)
      end
    end
  end
end