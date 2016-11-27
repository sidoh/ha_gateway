require 'pcap/pcaplet'

require_relative 'listener'
require_relative '../../helpers/pcap_helpers'

module HaGateway
  class ArpProbeDriver < HaGateway::Listener
    include PcapHelpers
    
    attr_reader :params
    
    def initialize(params = {})
      super(params)
    end
    
    def listen
      begin
        caplet = build_pcap_listener(params['interface'])
        caplet.add_filter('arp')
        
        caplet.each_packet do |packet|
          hw_addr = arp_src_addr(packet)
          selected_hw_addr = params['hw_addr'].downcase.gsub(':', '')
          
          if hw_addr == selected_hw_addr 
            logger.debug "Got ARP query from: #{hw_addr}"
            fire_event :probe_received
          end
        end
      rescue Pcap::PcapError => e
        logger.error "Error setting up Pcap listener: #{e}\n#{e.backtrace.join("\n")}"
      end
    end
    
    private
  end
end