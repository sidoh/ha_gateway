require 'thread/pool'

module HaGateway
  class CompositeDriver
    attr_reader :params

    def initialize(type, params, *drivers)
      @params = params
      @delegates = drivers
    end

    def method_missing(m, *args, &block)
      pool_size = params['parallelism'] || 1
      pool = Thread.pool(pool_size)

      @delegates.each do |d|
        pool.process {
          d.send(m, *args, &block)
        }
      end
    end
  end
end
