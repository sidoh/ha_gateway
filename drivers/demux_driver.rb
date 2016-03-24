module HaGateway
  class DemuxDriver
    attr_reader :params, :type

    def initialize(type, params, demux_mapping)
      @type = type
      @params = params
      @demux_mapping = demux_mapping
    end

    def method_missing(m, *args, &block)
      driver = @demux_mapping[m.to_s]

      if !driver
        raise RuntimeError,
          "Undefined method \"#{m}\" for this driver. Defined method: #{demux_mapping.keys.join(', ')}"
      end

      driver.send(m, *args, &block)
    end
  end
end
