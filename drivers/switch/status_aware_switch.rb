module HaGateway
  class StatusAwareSwitch
    def on
      internal_on if status != 'on'
    end
    
    def off
      internal_off if status != 'off'
    end
  end
end