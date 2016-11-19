require 'pcap/pcaplet'

require_relative 'listener'

module HaGateway
  class DashButtonDriver < HaGateway::Listener
    attr_reader :params
    
    def initialize(params = {})
      @params = params
    end
    
    def listen
      caplet = Pcap::Pcaplet.new
      caplet.add_filter(Pcap::Filter.new('src 0.0.0.0'))
      caplet.each_packet do |packet|
        hw_addr = packet.raw_data[6,6].bytes.map { |x| sprintf('%02x', x) }.join
        selected_hw_addr = params['hw_addr'].downcase.gsub(':', '')
        puts hw_addr
        
        if hw_addr == selected_hw_addr
          fire_event :pressed
        end
      end
    end
  end
end