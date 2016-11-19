require 'ledenet_api'

module HaGateway
  module ConfigProvider
    @@config = nil
    
    def smartthings_oauth_client
      settings = config_value('smartthings')
      
      @@smartthings_oauth_client ||= OAuth2::Client.new(
        settings['client_id'],
        settings['client_secret'],
        site: 'https://graph.api.smartthings.com',
        authorize_url: '/oauth/authorize',
        token_url: '/oauth/token'
      )
    end

    def ledenet_host
      model = 'HF-LPB100-ZJ200'
      LEDENET.
          discover_devices(expected_models: [model]).
          reject { |x| x.model != model }.
          first.
          ip
    end

    def security_enabled?
      config_value(:require_hmac_signatures) == true
    end

    def config_value(k)
      config[k.to_s]
    end

    private
      def config
        if !@@config
          @@config = YAML.load_file('config/ha_gateway.yml')
        end
        @@config
      end
  end
end
