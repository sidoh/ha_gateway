module HaGateway
  class App < Sinatra::Application
    RGB_PARAMS = ['r', 'g', 'b']

    get '/lights/:light_name' do
      driver = build_driver('lights', params['light_name'])

      content_type 'application/json'
      {status: driver.on?}.to_json
    end

    post '/lights/:light_name' do
      driver = build_driver('lights', params['light_name'])

      if params['status'] == 'on'
        driver.on
      elsif params['status'] == 'off'
        driver.off
      end

      if (RGB_PARAMS & params.keys) == RGB_PARAMS
        rgb = RGB_PARAMS.map { |x| params[x].to_i }
        ledenet_api.update_color(*rgb)
      end

      if params.include?('level')
        hsl_color = Color::RGB.new(*ledenet_api.current_color).to_hsl
        hsl_color.luminosity = params['level'].to_i

        adjusted_rgb = hsl_color.to_rgb.to_a.map { |x| (x * 255).to_i }

        ledenet_api.update_color(*adjusted_rgb)
      end

      status 200
      body '{"success": true}'
    end
  end
end
