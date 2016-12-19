require 'sinatra'
require 'sinatra/json'
require 'sinatra/param'
require 'sinatra/namespace'

require 'ledenet_api'
require 'bravtroller'
require 'easy_upnp'
require 'color'
require 'openssl'
require 'net/ping'

require 'open-uri'

require_relative 'helpers/config_provider'
require_relative 'helpers/security'

module HaGateway
  class App < Sinatra::Application
    before do
      if security_enabled?
        validate_request(request, params)
      end
      
      if request.content_type == 'application/json'
        request.body.rewind
        params.merge!(JSON.parse(request.body.read))
      end
      
      logger.info "Params: #{params.inspect}"
    end
    
    get '/:driver_type' do
      content_type 'application/json'
      get_devices(params[:driver_type]).keys.to_json
    end
  end
end

require_relative 'helpers/init'
require_relative 'routes/init'
