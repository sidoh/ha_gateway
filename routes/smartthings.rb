require 'oauth2'

module HaGateway
  class App < Sinatra::Application
    get '/smartthings/authorize' do
      url = smartthings_oauth_client.auth_code.authorize_url(
        redirect_uri: "#{request.base_url}/smartthings/callback",
        scope: 'app'
      )
      
      redirect url
    end
    
    get '/smartthings/callback' do
      code = params[:code]

      # Use the code to get the token.
      response = smartthings_oauth_client.auth_code.get_token(
          code, 
          redirect_uri: "#{request.base_url}/smartthings/callback", 
          scope: 'app'
      )

      # debug - inspect the running console for the
      # expires in (seconds from now), and the expires at (in epoch time)
      logger.info 'TOKEN EXPIRES IN ' + response.expires_in.to_s
      logger.info 'TOKEN EXPIRES AT ' + response.expires_at.to_s
      logger.info 'token = ' + response.token
    end
  end
end