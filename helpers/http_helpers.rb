require_relative 'config_provider'
require_relative 'security'

module HaGateway
  module HttpHelpers
    include ConfigProvider
    include Security
    
    def send_signed_http_request(method, url, params = {})
      if !url.start_with?('http')
        url = "#{config_value('site_location')}#{url}"
      end
      
      uri = URI(url)
      
      Net::HTTP.start(uri.host, uri.port) do |http|
        method = method.to_s.titleize
        request = Net::HTTP.const_get(method).new(uri)
        
        if params
          body = nil
          
          if params.is_a?(String)
            body = params
          else
            body = params.to_json
          end
          
          request.body = body
          request.content_type = 'application/json'
        
          hmac_headers(request.path, body).each do |header, value|
            request[header] = value
          end
        end
        
        http.request(request)
      end
    end
  end
end