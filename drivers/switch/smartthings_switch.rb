require_relative '../../helpers/http_helpers'

module HaGateway
  class SmartthingsSwitchDriver
    include HttpHelpers
    
    attr_reader :params
    
    def initialize(params)
      @params = params
    end
    
    def on
      send_smartthings_request(command: 'on')
    end
    
    def off
      send_smartthings_request(command: 'off')
    end
    
    private
    
    def send_smartthings_request(p)
      send_signed_http_request(
        :Put,
        "/smartthings/switches/#{params['device_id']}",
        p
      )
    end
  end
end