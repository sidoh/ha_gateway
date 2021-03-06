require 'active_support/inflector'
require 'oauth2'
require 'json'

module HaGateway
  class App < Sinatra::Application
    OAUTH_TOKEN_KEY = 'smartthings_oauth_token'
    SMARTTHINGS_ENDPOINT_URI = 'https://graph.api.smartthings.com/api/smartapps/endpoints'
    
    helpers do
      def smartthings_oauth_token
        load_state(OAUTH_TOKEN_KEY)
      end
      
      def smartthings_app_uri
        uri = URI.parse(SMARTTHINGS_ENDPOINT_URI)
        response = smartthings_request_with_uri(:get, uri)
        response.first['uri']
      end
      
      def smartthings_request(verb, path, params = {})
        uri = URI.parse("#{smartthings_app_uri}#{path}")
        smartthings_request_with_uri(verb, uri, params)
      end
      
      def smartthings_request_with_uri(verb, uri, params = {})
        request = smartthings_build_request(uri, verb, params)
        
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        response = http.request(request)
        
        if body = response.body
          JSON.parse(body)
        end
      end
      
      def smartthings_build_request(uri, verb, params)
        request = Net::HTTP.const_get(verb.to_s.titleize).new(uri)
        request['Authorization'] = "Bearer #{smartthings_oauth_token}"
        
        if params.any?
          request.body = URI.encode_www_form(params)
          request.content_type = 'multipart/form-data'
        end
        
        request
      end
      
      def smartthings_redirect_url(request)
        base = config_value('site_location') || request.base_url
        "#{base}/smartthings/callback"
      end
    end
    
    get '/smartthings/authorize' do
      url = smartthings_oauth_client.auth_code.authorize_url(
        redirect_uri: smartthings_redirect_url(request),
        scope: 'app'
      )
      
      redirect url
    end
    
    get '/smartthings/callback' do
      code = params[:code]

      response = smartthings_oauth_client.auth_code.get_token(
          code, 
          redirect_uri: smartthings_redirect_url(request),
          scope: 'app'
      )
      
      save_state(OAUTH_TOKEN_KEY, response.token)
      
      redirect '/smartthings/devices'
    end
    
    get '/smartthings/devices' do
      if !smartthings_oauth_token
        redirect '/smartthings/authorize'
      else
        content_type 'application/json'
        smartthings_request(:get, '/devices').to_json
      end
    end
    
    put '/smartthings/thermometers/:device_id' do
      path = "/thermometers/#{params['device_id']}?temperature=#{params['temperature']}"
      smartthings_request(:put, path).to_json
    end
    
    put '/smartthings/switches/:device_id' do
      path = "/switches/#{params['device_id']}?command=#{params['command']}"
      smartthings_request(:put, path).to_json
    end
    
    get '/smartthings/routines' do
      smartthings_request(:get, '/routines').to_json
    end
    
    get '/smartthings/routines/:routine' do
      path = "/routines/#{params['routine']}"
      smartthings_request(:get, path).to_json
    end
  end
end