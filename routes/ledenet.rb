module HaGateway
  class App < Sinatra::Application
    RGB_PARAMS = ['r', 'g', 'b']

    def ledenet_api
      if !@ledenet_api
        host = ledenet_host
        @ledenet_api = LEDENET::Api.new(host)
      end
      @ledenet_api
    end

    post '/leds' do
      if params['status'] == 'on'
        ledenet_api.on
      elsif params['status'] == 'off'
        ledenet_api.off
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
