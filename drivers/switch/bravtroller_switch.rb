require 'bravtroller'

module HaGateway
  class BravtrollerSwitchDriver
    attr_reader :params

    def initialize(params)
      @params = params
    end

    def on
      bravtroller.power_on(params['hw_addr'])
    end

    def off
      bravtroller.press_button('PowerOff')
    end

    private
      def bravtroller
        if !@bravtroller
          @bravtroller = Bravtroller::Remote.new(params['host'])
        end
        @bravtroller
      end
  end
end
