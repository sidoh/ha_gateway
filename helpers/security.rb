require 'openssl'
require 'securerandom'

require_relative 'config_provider'

module HaGateway
  module Security
    include ConfigProvider
    
    def sign_request(request)
      payload = SecureRandom.uuid
      timestamp = Time.now.to_i
      
      digest = OpenSSL::Digest.new('sha1')
      data = sprintf("%s%s", payload, timestamp)
      hmac = OpenSSL::HMAC.hexdigest(digest, config_value(:hmac_secret), data)
      
      request['X-Signature-Timestamp'] = timestamp
      request['X-Signature-Payload'] = payload
      request['X-Signature'] = hmac
    end
  end
end