module HaGateway
  class App < Sinatra::Application
    post '/switches/:switch_name' do
      driver = build_driver('switches', params['switch_name'])

      if params['status'] == 'on'
        driver.on
      elsif params['status'] == 'off'
        driver.off
      end
    end
  end
end
