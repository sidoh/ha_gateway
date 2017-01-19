require_relative '../../helpers/http_helpers'

module HaGateway
  class IrBlasterSwitchDriver
    include HttpHelpers
    
    attr_reader :params
    
    def initialize(params)
      @params = params
    end
    
    def on
      send_command(params['on'])
    end
    
    def off
      send_command(params['off'])
    end
    
    private
    
    def send_command(p)
      repeat = p['repeat'] || 1
      delay_ms = p['delay_ms'] || 100
      
      while (repeat -= 1) >= 0
        send_signed_http_request(
          :Post,
          params['url'],
          p['params']
        )
        
        sleep(delay_ms/1000.0) if repeat > 0
      end
    end
  end
end