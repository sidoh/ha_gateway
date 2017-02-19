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
    
    get '/switches/:switch_name' do
      driver = build_driver('switch', params['switch_name'])
      
      if driver.respond_to?(:status)
        driver.status
      else
        raise "This switch doesn't support status reporting"
      end
    end
  end
end
