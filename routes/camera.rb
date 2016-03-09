require 'uri'
require 'net/http'
require 'open3'
require 'crack'

module HaGateway
  class App < Sinatra::Application
    get '/camera/:camera_name/status.json' do
      r = camera_action(params['camera_name'], 'getDevState')

      content_type 'application/json'
      Crack::XML.parse(r)['CGI_Result'].to_json
    end

    get '/camera/:camera_name/snapshot.jpg' do
      content_type 'image/jpeg'
      r = camera_action(params['camera_name'], 'snapPicture2')

      if params[:rotate] and (true if Float(params[:rotate]) rescue false)
        Open3.popen3("convert - -rotate #{params[:rotate]} fd:1") do |i, o, e, t|
          i.write(r)
          i.close
          r = o.read
        end
      end

      r
    end

    get '/camera/:camera_name/stream.mjpeg' do
      stream_boundary = 'ThisString'
      content_type "multipart/x-mixed-replace;boundary=#{stream_boundary}"

      start_time = Time.now
      length = (params['length'] || -1).to_i

      stream do |out|
        buffer = ""

        stream_action(params['camera_name'], 'GetMJStream') do |chunk|
          if (i = chunk.index("--#{stream_boundary}")).nil?
            buffer << chunk
          else
            out << buffer
            out << chunk[0, i]

            buffer = chunk[i..-1]
          end

          if length > -1 and (Time.now - start_time).to_i >= length
            break
          end
        end
      end
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
      def stream_action(camera_name, action, options = {}, &block)
        options = { request_file: 'CGIStream.cgi' }.merge(options)

        camera_action(camera_name, action, options, &block)
      end

      def camera_action(camera_name, action, options = {}, &block)
        config = camera_config(camera_name)
        camera_params = {
          usr: config['username'],
          pwd: config['password'],
          cmd: action
        }.merge(options)

        uri = URI(camera_url(config['host'], camera_params))
        Net::HTTP.start(uri.host, uri.port) do |http|
          request = Net::HTTP::Get.new(uri)

          http.request(request) do |response|
            return response.read_body(&block)
          end
        end
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
        file = params[:request_file] || 'CGIProxy.fcgi'

        "http://#{host}/cgi-bin/#{file}?#{URI.encode_www_form(params)}"
      end
  end
end
