require 'sinatra'
require 'sinatra/json'

require 'ledenet_api'
require 'bravtroller'
require 'color'
require 'openssl'
require 'net/ping'

require 'open-uri'

require_relative 'helpers/config_provider'

module HaGateway
  class App < Sinatra::Application
    before do
      if security_enabled?
        timestamp = request.env['HTTP_X_SIGNATURE_TIMESTAMP']
        payload   = request.env['HTTP_X_SIGNATURE_PAYLOAD']
        signature = request.env['HTTP_X_SIGNATURE']

        if [payload, timestamp, signature].any?(&:nil?)
          logger.info "Access denied: incomplete signature params."
          logger.info "timestamp = #{timestamp}, payload = #{payload}, signature = #{signature}"
          halt 403
        end

        digest = OpenSSL::Digest.new('sha1')
        data = (payload + timestamp)
        hmac = OpenSSL::HMAC.hexdigest(digest, config_value[:hmac_key], data)

        if hmac != signature
          logger.info "Access denied: incorrect signature. Computed = '#{hmac}', provided = '#{signature}'"
          halt 403
        end

        if ((Time.now.to_i - 20) > timestamp.to_i)
          logger.info "Invalid parameter. Timestamp expired: #{timestamp}"
          halt 412
        end
      end
    end
  end
end

require_relative 'helpers/init'
require_relative 'routes/init'
