require 'pcap/pcaplet'

module HaGateway
  module PcapHelpers
    def build_pcap_listener(iface = nil)
      caplet_params = []
      
      if iface
        caplet_params << "-i #{iface}"
      end
      
      Pcap::Pcaplet.new(*caplet_params)
    end
    
    def arp_src_addr(packet)
      packet.raw_data[6,6].bytes.map { |x| sprintf('%02x', x) }.join
    end
  end
end