root = ::File.dirname(__FILE__)
require ::File.join( root, 'ha_gateway' )
run HaGateway::App.new
