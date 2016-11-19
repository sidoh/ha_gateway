require_relative 'helpers/config_provider'
require_relative 'helpers/driver_loader'

include HaGateway::ConfigProvider
include HaGateway::DriverLoader

config_value('listeners').each do |key, config|
  driver = build_driver_from_defn('listener', key, config)
  driver.listen
end
