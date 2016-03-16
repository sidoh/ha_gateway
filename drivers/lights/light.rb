module HaGateway
  class Light
    def method_missing(m)
      raise NoMethodError, "Driver #{self.class} does not support the method #{m}"
    end
  end
end
