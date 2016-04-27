root = ::File.dirname(__FILE__)
require ::File.join( root, 'ha_gateway' )
require 'sinatra'

configure do
  set :server, :puma
end

run HaGateway::App.new
