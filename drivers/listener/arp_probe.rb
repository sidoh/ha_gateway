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
        caplet.add_filter(Pcap::Filter.new('arp'))
        
        dedup_threshold = params['dedup_threshold'] || 0
        last_event = 0
        
        caplet.each_packet do |packet|
          hw_addr = packet.raw_data[6,6].bytes.map { |x| sprintf('%02x', x) }.join
          selected_hw_addr = params['hw_addr'].downcase.gsub(':', '')
          
          logger.debug "Got ARP query from: #{hw_addr}"
          
          if hw_addr == selected_hw_addr && current_timestamp > (last_event + dedup_threshold)
            last_event = current_timestamp
            
            begin 
              fire_event :probe_received
            rescue Exception => e
              logger.error "Caught exception when firing event: #{e}"
            end
          end
            
          logger.info "Last event: #{last_event}"
        end
      rescue Pcap::PcapError => e
        logger.error "Error setting up Pcap listener. This probably means you didn't start the process as root."
      end
    end
    
    private
    
    def current_timestamp
      (Time.now.to_f*1000).to_i
    end
  end
end