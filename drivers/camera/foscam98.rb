require 'uri'
require 'net/http'
require 'open3'
require 'crack'
require 'ruby-enum'

module HaGateway
  class Foscam98Driver
    attr_reader :params

    STREAM_BOUNDARY = 'ThisString'
    
    # In order of least to most sensitive
    ORDERED_SENSITIVITIES = [4, 3, 0, 1, 2]

    class IrMode
      include Ruby::Enum

      define :ON, 'on'
      define :OFF, 'off'
      define :AUTO, 'auto'
    end

    def initialize(params = {})
      @username = params['username']
      @password = params['password']
      @hostname = params['host']
    end

    def snapshot(&block)
      camera_action('snapPicture2', &block)
    end

    def open_mjpeg_stream(params = {}, &block)
      buffer = ''

      stream_action('GetMJStream') do |chunk|
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
      parse_result(camera_action('getDevState'))
    end

    def ir_mode=(mode)
      raise RuntimeError, "Unknown ir mode: #{mode}" unless IrMode.value?(mode)

      autoMode = (mode == IrMode::AUTO)

      camera_action(
          'setInfraLedConfig',
          mode: autoMode ? '0' : '1'
      )

      if !autoMode
        camera_action(
            action = (mode == IrMode::ON) ? 'openInfraLed' : 'closeInfraLed'
        )
      end
    end

    def preset=(preset)
      camera_action(
          'ptzGotoPresetPoint',
          name: preset
      )
    end

    def recording=(recording)
      camera_params = {
        isEnable: 1,
        recordLevel: 4,
        spaceFullMode: 0,
        isEnableAudio: 0
      }

      camera_action(
          'setScheduleRecordConfig',
          camera_params.merge(schedule_params(recording))
      )
    end

    def remote_access=(remote_access)
      camera_action(
          'setP2PEnable',
          enable: remote_access ? '1' : '0'
      )
    end
    
    def motion_detection=(motion_detection)
      update_motion_detection_config(
        {
          'isEnable' => motion_detection ? '1' : '0',
        }.merge(schedule_params(true))
      )
    end
    
    def motion_detection_sensitivity=(sensitivity)
      update_motion_detection_config(
          'sensitivity' => convert_sensitivity(sensitivity)
      )
    end
    
    def motion_detection_config
      parse_result(camera_action('getMotionDetectConfig'))
    end
    
    def update_motion_detection_config(params)
      camera_action(
          'setMotionDetectConfig',
          motion_detection_config.merge(params)
      )
    end

    private
      # The schedule is configured by 7 vars, one for each day of the week. The value
      # for each var is a bitmask of length 48, with each bit representing a 30
      # minute window. If, for example, the most significant bit is set to 1, then
      # scheduled recording for that day is enabled from 00:00:00 -- 00:29:59.
      def schedule_params(on)
        schedule_params = {}
        value = on ? (2**48 - 1) : 0
        (0..6).each { |i| schedule_params["schedule#{i}"] = value }
        schedule_params
      end
    
      def parse_result(r)
        Crack::XML.parse(r)['CGI_Result']
      end
      
      def convert_sensitivity(value)
        i = ((value/100.0) * ORDERED_SENSITIVITIES.count).floor
        i = [ORDERED_SENSITIVITIES.count - 1, i].min
        ORDERED_SENSITIVITIES[i]
      end
    
      def stream_action(action, options = {}, &block)
        options = { request_file: 'CGIStream.cgi' }.merge(options)

        camera_action(action, options, &block)
      end

      def camera_action(action, options = {}, &block)
        camera_params = {
          usr: @username,
          pwd: @password,
          cmd: action
        }.merge(options)

        uri = URI(camera_url(@hostname, camera_params))
        Net::HTTP.start(uri.host, uri.port) do |http|
          request = Net::HTTP::Get.new(uri)

          http.request(request) do |response|
            return response.read_body(&block)
          end
        end
      end

      def camera_url(host, params)
        file = params[:request_file] || 'CGIProxy.fcgi'

        "http://#{host}/cgi-bin/#{file}?#{URI.encode_www_form(params)}"
      end
  end
end
