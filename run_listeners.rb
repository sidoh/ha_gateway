require 'optparse'

require_relative 'helpers/config_provider'
require_relative 'helpers/driver_loader'
require_relative 'helpers/pcap_helpers'

include HaGateway::ConfigProvider
include HaGateway::DriverLoader

options = {}

$stdout.sync = true

OptionParser.new do |opts|
  opts.on('--requires-sudo', 'Check if script requires sudo') do
    options[:check_sudo] = true
  end
  
  opts.on('--arp-sniff', "Don't run listeners; listen for ARP packets") do
    options[:arp_sniff] = true
  end
  
  opts.on('--interface [iface]', String, 'Interface to listen on') do |v|
    options[:interface] = v
  end
end.parse!

if options[:arp_sniff]
  include HaGateway::PcapHelpers
  pcap = build_pcap_listener(options[:interface])
  pcap.add_filter('arp')
  
  pcap.each_packet do |packet|
    puts "Got ARP packet from: #{arp_src_addr(packet)}"
  end
  
  exit
end
  
listeners = config_value('listeners') || []

if options[:check_sudo]
  needs_sudo = listeners.any? do |_, config|
    %(arp_probe tcpdump_monitor).include? config['driver']
  end
  
  puts needs_sudo
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
