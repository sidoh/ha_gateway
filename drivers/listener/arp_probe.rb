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
        caplet = build_pcap_listener(params['interface'])
        caplet.add_filter('arp')
        
        dedup_threshold = params['dedup_threshold'] || 0
        last_event = 0
        
        caplet.each_packet do |packet|
          hw_addr = arp_src_addr(packet)
          selected_hw_addr = params['hw_addr'].downcase.gsub(':', '')
          
          if hw_addr == selected_hw_addr && current_timestamp > (last_event + dedup_threshold)
            logger.debug "Got ARP query from: #{hw_addr}"
            fire_event :probe_received
            last_event = current_timestamp
          end
        end
      rescue Pcap::PcapError => e
        logger.error "Error setting up Pcap listener: #{e}\n#{e.backtrace.join("\n")}"
      end
    end
    
    private
    
    def current_timestamp
      (Time.now.to_f*1000).to_i
    end
  end
end