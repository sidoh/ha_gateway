module HaGateway
  class RepeatWrapper
    def initialize(delegate, times)
      raise RuntimeError "repeat count should be >= 1" unless times >= 1

      @delegate = delegate
      @times = times
    end

    def method_missing(m, *args, &block)
      @times.times { @delegate.call(m, args, block) }
    end
  end
end
