require 'pcap/pcaplet'

require_relative 'listener'

module HaGateway
  class ArpProbeDriver < HaGateway::Listener
    attr_reader :params
    
    def initialize(params = {})
      @params = params
    end
    
    def listen
      begin
        caplet = Pcap::Pcaplet.new
        caplet.add_filter(Pcap::Filter.new('src 0.0.0.0'))
        caplet.each_packet do |packet|
          hw_addr = packet.raw_data[6,6].bytes.map { |x| sprintf('%02x', x) }.join
          selected_hw_addr = params['hw_addr'].downcase.gsub(':', '')
          
          logger.info "Got ARP query from: #{hw_addr}"
          
          if hw_addr == selected_hw_addr
            fire_event :probe_received
          end
        end
      rescue Pcap::PcapError => e
        logger.error "Error setting up Pcap listener. This probably means you didn't start the process as root."
      end
    end
  end
end