module HaGateway
  class CompositeDriver
    attr_reader :params

    def initialize(type, *drivers)
      @params = params
      @delegates = drivers
    end

    def method_missing(m, *args, &block)
      @delegates.each { |d| d.send(m, *args, &block) }
    end
  end
end
