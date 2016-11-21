require 'net/http'
require 'active_support/inflector'
require 'logger'

require_relative '../../helpers/config_provider'
require_relative '../../helpers/security'

module HaGateway
  class Listener
    attr_reader :params
    
    include ConfigProvider
    include Security
    
    def initialize(params = {})
      @params = params
    end
    
    def fire_event(event, *args)
      event = event.to_s
      
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
    
    def http_event(http_config, *args)
      begin
        url = http_config['url']
        
        if !url.start_with?('http')
          url = "#{config_value('site_location')}#{url}"
        end
        
        uri = URI(url)
        
        Net::HTTP.start(uri.host, uri.port) do |http|
          method = http_config['method'].titleize
          request = Net::HTTP.const_get(method).new(uri)
          
          if http_config['params']
            request.body = URI.encode_www_form(http_config['params'])
            request.content_type = 'multipart/form-data'
          end
          
          sign_request(request)
          
          http.request(request)
        end
      rescue NameError => e
        raise "Undefined HTTP method '#{http_config['method']}'"
      end
    end
  end
end