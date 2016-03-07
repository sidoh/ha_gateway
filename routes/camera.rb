module HaGateway
  class App < Sinatra::Application
    get '/camera/:camera_name/snapshot.jpg' do
      content_type 'image/jpeg'
      camera_action(params['camera_name'], 'snapPicture2') { |f| f.read }
    end

    post '/camera/:camera_name' do
      if params['recording']
        camera_params = {
          isEnable: 1,
          recordLevel: 4,
          spaceFullMode: 0,
          isEnableAudio: 0
        }

        # The schedule is configured by 7 vars, one for each day of the week. The value
        # for each var is a bitmask of length 48, with each bit representing a 30
        # minute window. If, for example, the most significant bit is set to 1, then
        # scheduled recording for that day is enabled from 00:00:00 -- 00:29:59.
        value = params['recording'] == 'true' ? (2**48 - 1) : 0
        (0..6).each { |i| camera_params["schedule#{i}"] = value }

        camera_action(
            params['camera_name'],
            'setScheduleRecordConfig',
            camera_params
        )
      end

      if params['preset']
        camera_action(
            params['camera_name'],
            'ptzGotoPresetPoint',
            name: params['preset']
        )
      end

      status 200
    end

    private
      def camera_action(camera_name, action, options = {}, &block)
        config = camera_config(camera_name)
        camera_params = {
          usr: config['username'],
          pwd: config['password'],
          cmd: action
        }.merge(options)

        url = camera_url(config['host'], camera_params)
        open(url, &block)
      end

      def camera_config(camera_name)
        config = config_value(:cameras)

        if config.nil? or (cc = config[camera_name]).nil?
          raise RuntimeError, "Unknown camera: #{camera_name}"
        else
          cc
        end
      end

      def camera_url(host, params)
        "http://#{host}/cgi-bin/CGIProxy.fcgi?#{URI.encode_www_form(params)}"
      end
  end
end
