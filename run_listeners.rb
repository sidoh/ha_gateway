require_relative 'helpers/config_provider'
require_relative 'helpers/driver_loader'

include HaGateway::ConfigProvider
include HaGateway::DriverLoader

threads = []

config_value('listeners').each do |key, config|
  driver = build_driver_from_defn('listener', key, config)
  
  threads << Thread.new do
    driver.listen
  end
end

threads.each(&:join)
