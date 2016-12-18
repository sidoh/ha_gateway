require 'open3'

module HaGateway
  class App < Sinatra::Application
    STREAM_BOUNDARY = "__BOUNDARY__"

    namespace '/cameras/:camera_name' do
      helpers do 
        def driver
          @driver ||= build_driver('camera', params['camera_name'])
        end
      end
      
      get '/status.json' do
        content_type 'application/json'
        driver.status.to_json
      end

      get '/snapshot.jpg' do
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

      get '/stream.mjpeg' do
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

      put do
        param :recording,       String, in: %w(true false)
        param :preset,          String
        param :irMode,          String, in: %w(on off auto)
        param :remoteAccess,    String, in: %w(true false)
        param :motionDetection, Object

        driver = build_driver('camera', params['camera_name'])

        if params['recording']
          driver.recording = (params['recording'] == 'true')
        end

        if params['irMode']
          driver.ir_mode = params['irMode']
        end

        if params['remoteAccess']
          driver.remote_access = (params['remoteAccess'] == 'true')
        end
        
        if md_params = params['motionDetection']
          if md_params.include? 'enabled'
            driver.motion_detection = (md_params['enabled'].to_s == 'true')
          end
          
          if md_params['sensitivity']
            driver.motion_detection_sensitivity = md_params['sensitivity'].to_i
          end
        end

        status 200
      end
      
      post '/move' do
        param :direction, String
        param :amount, Integer, min: 1, max: 100, default: 1
        
        driver.move params[:direction], params[:amount]
        
        status 200
      end
      
      get '/presets' do
        content_type 'application/json'
        driver.presets.to_json
      end
      
      post '/presets' do
        param :name, String
        
        driver.save_preset(params['name'])
        
        status 200
      end
      
      delete '/presets/:preset_name' do
        driver.delete_preset(params[:preset_name])
        
        status 200
      end
      
      get '/presets/:preset_name' do
        driver.goto_preset(params[:preset_name])
        
        status 200
      end
    end
  end
end
