module HaGateway
  class App < Sinatra::Application
    RGB_PARAMS = ['r', 'g', 'b']

    get '/light/:light_name' do
      driver = build_driver('light', params['light_name'])

      content_type 'application/json'
      {status: driver.on?}.to_json
    end

    put '/light/:light_name' do
      param :status, String, in: ['on', 'off'], transform: :downcase
      param :r,      Integer, range: (0..255)
      param :g,      Integer, range: (0..255)
      param :b,      Integer, range: (0..255)
      param :level,  Float, range: (0..100)

      driver = build_driver('light', params['light_name'])

      if params['status'] == 'on'
        driver.on
      elsif params['status'] == 'off'
        driver.off
      end

      if (RGB_PARAMS & params.keys) == RGB_PARAMS
        rgb = RGB_PARAMS.map { |x| params[x].to_i }
        driver.color(*rgb)
      end

      if params.include?('level')
        driver.level(params['level'].to_i)
      end

      status 200
      body '{"success": true}'
    end
  end
end
