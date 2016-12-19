require 'openssl'

require_relative 'config_provider'

module HaGateway
  module Security
    include ConfigProvider
    
    def hmac_headers(path, params)
      timestamp = Time.now.to_i
      body = ''
      
      if params.is_a?(String)
        body = params
      elsif params.is_a?(Hash)
        body = params.sort.join
      else
        raise "Unsupported type: #{params.class}, value: #{params.inspect}"
      end
      
      digest = OpenSSL::Digest.new('sha1')
      payload = sprintf("%s%s%s", path, body, timestamp)
      hmac = OpenSSL::HMAC.hexdigest(digest, config_value(:hmac_secret), payload)
      
      {
        'X-Signature-Timestamp' => timestamp,
        'X-Signature' => hmac
      }
    end
    
    def validate_request(request, params)
      timestamp = request.env['HTTP_X_SIGNATURE_TIMESTAMP'] || '0'
      signature = request.env['HTTP_X_SIGNATURE'] || ''
      body = ''
      
      if request.content_type == 'application/json'
        request.body.rewind
        body = request.body.read
      else
        signed_params = (request.put? || request.post?) ? request.POST : {}
        body = signed_params.sort.join
      end
        
      payload = request.path_info + body + timestamp
        
      if [payload, timestamp, signature].any?(&:nil?)
        logger.info "Access denied: incomplete signature params."
        logger.info "timestamp = #{timestamp}, payload = #{payload}, signature = #{signature}"
        halt 403
      end
        
      digest = OpenSSL::Digest.new('sha1')
      hmac = OpenSSL::HMAC.hexdigest(digest, config_value(:hmac_secret), payload)

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