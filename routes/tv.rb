module HaGateway
  class App < Sinatra::Application
    get '/tv' do
      ping = Net::Ping::External.new(config_value(:bravia_host))
      tv_status = ping.ping? ? 'on' : 'off'

      status 200
      json status: tv_status
    end

    post '/tv' do
      bravtroller = Bravtroller::Remote.new(Bravtroller::Client.new(config_value(:bravia_host)))

      if params['status'] == 'on'
        bravtroller.power_on(config_value(:bravia_hw_addr))
      elsif params['status'] == 'off'
        bravtroller.press_button('PowerOff')
      end
    end
  end
end
