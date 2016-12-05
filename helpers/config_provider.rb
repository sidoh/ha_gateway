require 'yaml'
require 'ledenet_api'

module HaGateway
  module ConfigProvider
    @@config = nil
    
    def smartthings_oauth_client
      settings = config_value('smartthings')
      
      if !settings
        raise "Missing top-level settings key `smartthings`."
      end
      
      client_id = settings['client_id']
      client_secret = settings['client_secret']
      
      raise "Missing OAuth client_id" if !client_id
      raise "Missing OAuth client_secret" if !client_secret
      
      @@smartthings_oauth_client ||= OAuth2::Client.new(
        client_id,
        client_secret,
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
