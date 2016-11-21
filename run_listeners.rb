require 'optparse'

require_relative 'helpers/config_provider'
require_relative 'helpers/driver_loader'

include HaGateway::ConfigProvider
include HaGateway::DriverLoader

options = {}

$stdout.sync = true

OptionParser.new do |opts|
  opts.on('--requires-sudo', 'Check if script requires sudo') do
    options[:check_sudo] = true
  end
end.parse!
  
listeners = config_value('listeners') || []

if options[:check_sudo]
  has_arp_probe = listeners.any? do |_, config|
    config['driver'] == 'arp_probe'
  end
  
  puts has_arp_probe
  exit
end

threads = []

listeners.each do |key, config|
  driver = build_driver_from_defn('listener', key, config)
  
  threads << Thread.new do
    driver.listen
  end
end

threads.each(&:join)
