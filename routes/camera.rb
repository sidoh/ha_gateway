require 'open3'

module HaGateway
  class App < Sinatra::Application
    STREAM_BOUNDARY = "__BOUNDARY__"

    get '/cameras/:camera_name/status.json' do
      driver = build_driver('camera', params['camera_name'])

      content_type 'application/json'
      driver.status.to_json
    end

    get '/cameras/:camera_name/snapshot.jpg' do
      param :rotate, Integer, range: (0..360)

      driver = build_driver('camera', params['camera_name'])

      content_type 'image/jpeg'
      r = driver.snapshot

      if params[:rotate] and (true if Float(params[:rotate]) rescue false)
        Open3.popen3("convert - -rotate #{params[:rotate]} fd:1") do |i, o, e, t|
          i.write(r)
          i.close
          r = o.read
        end
      end

      r
    end

    get '/cameras/:camera_name/stream.mjpeg' do
      param :length, Integer, min: 1

      driver = build_driver('camera', params['camera_name'])
      content_type "multipart/x-mixed-replace;boundary=#{STREAM_BOUNDARY}"

      start_time = Time.now
      length = (params['length'] || -1).to_i

      stream do |out|
        buffer = ""

        driver.open_mjpeg_stream do |frame|
          out << frame
          out << "--#{STREAM_BOUNDARY}"

          if length > -1 and (Time.now - start_time).to_i >= length
            break
          end
        end
      end
    end

    put '/cameras/:camera_name' do
      param :recording,    String, in: ['true', 'false']
      param :preset,       String
      param :irMode,       String, in: ['on', 'off', 'auto']
      param :remoteAccess, String, in: ['true', 'false']

      driver = build_driver('camera', params['camera_name'])

      if params['recording']
        driver.recording = (params['recording'] == 'true')
      end

      if params['preset']
        driver.preset = params['preset']
      end

      if params['irMode']
        driver.ir_mode = params['irMode']
      end

      if params['remoteAccess']
        driver.remote_access = (params['remoteAccess'] == 'true')
      end

      status 200
    end
  end
end
