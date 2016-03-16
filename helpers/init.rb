require_relative 'config_provider'
HaGateway::App.helpers HaGateway::ConfigProvider

require_relative 'driver_loader'
HaGateway::App.helpers HaGateway::DriverLoader
