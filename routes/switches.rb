module HaGateway
  class App < Sinatra::Application
    put '/switches/:switch_name' do
      param :status, String, in: ['on', 'off'], transform: :downcase

      driver = build_driver('switch', params['switch_name'])

      if params['status'] == 'on'
        driver.on
      elsif params['status'] == 'off'
        driver.off
      end
    end
  end
end
