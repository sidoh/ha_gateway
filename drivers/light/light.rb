module HaGateway
  class Light
    def api
      if !@api
        @api = build_api
      end
      @api
    end
  end
end
