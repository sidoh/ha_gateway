require 'openssl'

require_relative 'config_provider'

module HaGateway
  module Security
    include ConfigProvider
    
    def hmac_headers(path, params = {})
      timestamp = Time.now.to_i
      
      digest = OpenSSL::Digest.new('sha1')
      payload = sprintf("%s%s%s", path, params.sort.join, timestamp)
      hmac = OpenSSL::HMAC.hexdigest(digest, config_value(:hmac_secret), payload)
      
      {
        'X-Signature-Timestamp' => timestamp,
        'X-Signature' => hmac
      }
    end
  end
end