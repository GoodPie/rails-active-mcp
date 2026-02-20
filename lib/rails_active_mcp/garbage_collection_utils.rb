# frozen_string_literal: true

module RailsActiveMcp
  class GarbageCollectionUtils
    # Probabilistic garbage collection for long-running processes
    # Not sure if this is the best approach but it's a quick common pattern that works
    def self.probalistic_clean!
      return unless defined?(::ActiveRecord::Base)

      # Clean up connections to prevent pool exhaustion
      # Rails 7.2+ removed clear_active_connections! from ActiveRecord::Base
      if ::ActiveRecord::Base.connection_pool.respond_to?(:release_connection)
        ::ActiveRecord::Base.connection_pool.release_connection
      elsif ::ActiveRecord::Base.respond_to?(:clear_active_connections!)
        ::ActiveRecord::Base.clear_active_connections!
      end
      GC.start if rand(100) < 5
    end
  end
end
