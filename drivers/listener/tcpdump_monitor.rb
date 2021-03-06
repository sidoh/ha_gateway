require 'open3'

require_relative 'listener'
require_relative '../../helpers/pcap_helpers'

module HaGateway
  class TcpdumpMonitorDriver < HaGateway::Listener
    attr_reader :params
    
    def initialize(params = {})
      super(params)
      
      `which tcpdump`
      if !$?.success?
        raise "Couldn't find tcpdump. tcpdump_monitor won't work without it."
      end
    end
    
    def listen
      args = ['tcpdump']
      
      if interface = params['interface']
        args += %W(-i #{interface})
      end
      
      if hw_addr = params['hw_addr']
        args << "ether host #{hw_addr}"
      end
      
      args += %w(-q -p -c 1)
      
      while true 
        Open3.popen3(*args) do |_, stdout, stderr, pthread|
          line = stdout.gets
          
          if pthread.value != 0
            raise "Error running tcpdump. Usually means process not running as root, or the monitor device does not exist.\n" <<
                  "Error output: #{stderr.read}"
          end
            
          logger.debug "Read line from tcpdump: #{line}"
          
          fire_event :read_packet
        end
      end
    end
  end
end
