require_relative '../upnp_driver'

module HaGateway
  class UpnpSwitchDriver < HaGateway::UpnpDriver
    def initialize(params)
      super(params)

      define_actions :on, :off
    end
  end
end
