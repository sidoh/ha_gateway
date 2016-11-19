require_relative 'config_provider'

module HaGateway
  module Persistence
    include ConfigProvider
    
    def save_state(key, value)
      current = load_all_state
      current[key] = value
      File.open(state_path, 'w') do |f|
        f.write YAML.dump(current)
      end
    end
    
    def load_state(key)
      load_all_state[key]
    end
    
    private
      def state_path
        config_value('persistence_path')
      end
      
      def load_all_state
        if File.exist?(state_path)
          YAML.load_file(state_path) || {}
        else
          {}
        end
      end
  end
end