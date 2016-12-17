require 'uri'
require 'net/http'
require 'open3'
require 'crack'
require 'ruby-enum'

module HaGateway
  class Amcrest721Driver
    attr_reader :params

    STREAM_BOUNDARY = 'myboundary'

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
      r = camera_action('getDevState')
      Crack::XML.parse(r)['CGI_Result']
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

    def recording=(recording)
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
      value = recording ? (2**48 - 1) : 0
      (0..6).each { |i| camera_params["schedule#{i}"] = value }

      camera_action(
          'setScheduleRecordConfig',
          camera_params
      )
    end

    def remote_access=(remote_access)
      camera_action(
          'setP2PEnable',
          enable: remote_access ? '1' : '0'
      )
    end

    private
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
        "http://#{host}/cgi-bin/#{endpoint}?#{URI.encode_www_form(params)}"
      end
  end
end
