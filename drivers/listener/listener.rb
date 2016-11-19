require 'net/http'
require 'active_support/inflector'

module HaGateway
  class Listener
    attr_reader :params
    
    def initialize(params = {})
      @params = params
    end
    
    def fire_event(event, *args)
      event = event.to_s
      
      if event_config = params['events'][event]
        if http_config = event_config['http']
          http_event(http_config, *args)
        end
      end
    end
    
    private
    
    def http_event(http_config, *args)
      begin
        uri = URI(http_config['url'])
        
        Net::HTTP.start(uri.host, uri.port) do |http|
          method = http_config['method'].titleize
          request = Net::HTTP.const_get(method).new(uri)
          
          if http_config['params']
            request.body = URI.encode_www_form(http_config['params'])
            request.content_type = 'multipart/form-data'
          end
          
          http.request(request)
        end
      rescue NameError => e
        raise "Undefined HTTP method '#{http_config['method']}'"
      end
    end
  end
end