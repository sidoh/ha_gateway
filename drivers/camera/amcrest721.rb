require 'uri'
require 'net/http'
require 'open3'
require 'crack'
require 'ruby-enum'

module HaGateway
  class Amcrest721Driver
    attr_reader :params

    STREAM_BOUNDARY = 'myboundary'
    
    DIRECTIONS = %w(
      Up Down Left Right LeftUp RightUp LeftDown RightDown
    )

    module RecordMode
      VALUES = [
        REGULAR = 1,
        MOTION = 2,
        ALARM = 4,
        CARD = 8
      ]
    end

    def initialize(params = {})
      @username = params['username']
      @password = params['password']
      @hostname = params['host']
    end

    def snapshot(&block)
      camera_action('snapshot.cgi', &block)
    end

    def open_mjpeg_stream(params = {}, &block)
      buffer = ''

      stream_action('video.cgi', subtype: 1) do |chunk|
        if (i = chunk.index("--#{STREAM_BOUNDARY}")).nil?
          buffer << chunk
        else
          buffer << chunk[0, i]
          yield(buffer)

          s = (i + "--#{STREAM_BOUNDARY}".length)

          if s < chunk.length
            buffer = chunk[s..-1]
          else
            buffer.clear
          end
        end
      end
    end

    def status
      {}
    end

    def recording=(recording)
      camera_action(
        'configManager.cgi',
        {
          'action' => 'setConfig'
        }.merge(schedule_params(RecordMode::REGULAR, recording))
      )
    end

    def remote_access=(remote_access)
      camera_action(
          'configManager.cgi',
          'action' => 'setConfig',
          'T2UServer.Enable' => remote_access.to_s
      )
    end
    
    def presets
      result = camera_action(
          'ptz.cgi', 
          action: 'getPresets',
          channel: 0
      )
      
      # What a mess
      lines = result.split("\n")
      index_lines = lines.select { |x| x[".Index="] }
      
      index_lines.map do |l|
        l.match(/\.Index=(\d+)/)[1]
      end
    end
    
    def save_preset(name)
      camera_action(
          'ptz.cgi',
          action: 'start',
          code: 'SetPreset',
          channel: 0,
          arg1: 0,
          arg2: name,
          arg3: 0,
          arg4: 0
      )
    end
    
    def goto_preset(preset)
      camera_action(
          'ptz.cgi',
          action: 'start',
          code: 'GotoPreset',
          channel: 0,
          arg1: 0,
          arg2: preset,
          arg3: 0,
          arg4: 0
      )
    end
    
    def delete_preset(name)
      camera_action(
          'ptz.cgi',
          action: 'start',
          code: 'ClearPreset',
          channel: 0,
          arg1: 0,
          arg2: name,
          arg3: 0,
          arg4: 0
      )
    end
    
    def motion_detection=(motion_detection)
      update_motion_detection_config(
        {
          'MotionDetect[0].Enable' => motion_detection
        }.merge(schedule_params(RecordMode::MOTION, motion_detection))
      )
    end
    
    def motion_detection_sensitivity=(sensitivity)
      update_motion_detection_config(
          'MotionDetect[0].MotionDetectWindow[0].Sensitive' => sensitivity
      )
    end
    
    def motion_detection_config
      parse_result(camera_action('getMotionDetectConfig'))
    end
    
    def update_motion_detection_config(params)
      camera_action(
          'configManager.cgi',
          { 'action' => 'setConfig' }.merge(params)
      )
    end
    
    def move(dir, amount)
      if !DIRECTIONS.include?(dir.to_s)
        raise "Unsupported direction: #{dir}. Supported directions: #{DIRECTIONS.join(', ')}"
      end
      
      camera_action(
        'ptz.cgi',
        action: 'start',
        code: dir,
        channel: 0,
        arg1: 0,
        arg2: 8,
        arg3: 0,
        arg4: 0
      )
      
      sleep ((amount - 1)/100.0)
      
      camera_action(
        'ptz.cgi',
        action: 'stop',
        code: dir,
        channel: 0,
        arg1: 0,
        arg2: 8,
        arg3: 0,
        arg4: 0
      )
    end

    private
    
    def convert_sensitivity(value)
      (value/100.0)*6
    end
    
    def schedule_params(mode, on)
      params = {}
      range = "00:00:00-#{on ? "23:59:59" : "00:00:00"}"
      
      (0..6).each do |i|
        params["Record[0].TimeSection[#{i}][0]"] = "#{mode} #{range}"
      end
      
      params
    end
    
    def stream_action(endpoint, options = {}, &block)
      camera_action(endpoint, options, &block)
    end

    def camera_action(endpoint, options = {}, &block)
      uri = URI(camera_url(@hostname, endpoint, options))
      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Get.new(uri)
        request.basic_auth(@username, @password)

        http.request(request) do |response|
          return response.read_body(&block)
        end
      end
    end

    def camera_url(host, endpoint, params)
      # Would love to use URI.encode_www_form here, but amcrest seems to barf
      # unless it receives the raw text.
      query_str = params.reduce([]) do |a, e|
        k, v = e.map(&:to_s)
        k = k.gsub(' ', '%20')
        v = v.gsub(' ', '%20')
        
        a.push("#{k}=#{v}")
      end
      query_str = query_str.join('&')
      
      "http://#{host}/cgi-bin/#{endpoint}?#{query_str}"
    end
  end
end
