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
        caplet_params = []
        
        if iface = params['interface']
          caplet_params << "-i #{iface}"
        end
        
        caplet = Pcap::Pcaplet.new(*caplet_params)
        caplet.add_filter(Pcap::Filter.new('arp'))
        
        dedup_threshold = params['dedup_threshold'] || 0
        last_event = 0
        
        caplet.each_packet do |packet|
          hw_addr = packet.raw_data[6,6].bytes.map { |x| sprintf('%02x', x) }.join
          selected_hw_addr = params['hw_addr'].downcase.gsub(':', '')
          
          logger.debug "Got ARP query from: #{hw_addr}"
          
          if hw_addr == selected_hw_addr && current_timestamp > (last_event + dedup_threshold)
            last_event = current_timestamp
            
            fire_event :probe_received
          end
            
          logger.info "Last event: #{last_event}"
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