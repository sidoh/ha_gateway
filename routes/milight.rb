require 'limitless_led'

module HaGateway
  class App < Sinatra::Application
    def milight_api
      if !@milight_api
        @milight_api = LimitlessLed::Bridge.new(host: config_value(:milight_host))
      end
      @milight_api
    end

    post '/milight' do
      if params['status'] == 'on'
        milight_api.all_on
      elsif params['status'] == 'off'
        milight_api.all_off
      end

      true
    end
  end
end
