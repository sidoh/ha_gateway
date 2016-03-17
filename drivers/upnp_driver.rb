require 'easy_upnp/ssdp_searcher'

module HaGateway
  class UpnpDriver
    attr_reader :params

    def initialize(params = {})
      @params = params
    end

    def client
      if !@client
        @client = build_client
      end
      @client
    end

    def run_action(action, action_settings)
      method = action_settings['method']
      args = action_settings['args']

      client.send(method, args)
    end

    def define_actions(*actions)
      actions.each do |action|
        action = action.to_s

        define_singleton_method(action) do
          if params['actions'].nil?
            raise RuntimeError, "No actions defined for this driver."
          elsif (action_settings = params['actions'][action]).nil?
            raise RuntimeError, "Action \"#{action}\" not defined for this driver. Defined actions: #{params['actions']}"
          end

          run_action(action, action_settings)
        end
      end
    end

    private
      def build_client
        device = EasyUpnp::SsdpSearcher.new.
            search('ssdp:all').
            reject { |x| x.uuid != params['uuid'] }.
            first

        if device.nil?
          raise RuntimeError, "Unable to find UPnP device with UUID: #{params['uuid']}"
        end

        service = device.service(params['service'])

        if service.nil?
          raise RuntimeError, "Service \"#{params['service']}\" undefined for device with UUID: #{params['uuid']}"
        end

        service
      end
  end
end
