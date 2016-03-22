module HaGateway
  class NoOpDriver
    def initialize(params = {})
      @params = params
    end

    def method_missing(m, *args, &block)
    end
  end
end
