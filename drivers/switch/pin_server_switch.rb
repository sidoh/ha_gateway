require 'open-uri'
require_relative 'status_aware_switch'
require_relative '../../helpers/http_helpers'

module HaGateway
  class PinServerSwitchDriver < StatusAwareSwitch
    include HttpHelpers
    
    attr_reader :params
    
    def initialize(params)
      @params = params
    end
    
    def status
      response = send_signed_http_request(
        :Get,
        pin_url(params['status_pin'])
      )
      status = response.body
      
      if known_statuses = params['statuses']
        known_statuses.map do |k, v|
          if k.to_s == status
            status = v
            break
          end
        end
      end
      
      status
    end
    
    private
    
    def internal_on
      send_command(params['commands']['on'])
    end
    
    def internal_off
      send_command(params['commands']['off'])
    end
    
    def pin_url(pin)
      "#{params['host']}/pins/#{pin}"
    end
    
    def send_command(cmd)
      response = send_signed_http_request(
        :Put,
        pin_url(params['pin']),
        cmd
      )
      
      if response.code == '200'
        true
      else
        raise "Error sending request: #{response.code}\n#{response.body}"
      end
    end
  end
end