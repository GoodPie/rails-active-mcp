# frozen_string_literal: true

module RailsActiveMcp
  class GarbageCollectionUtils
    # Probabilistic garbage collection for long-running processes
    # Not sure if this is the best approach but it's a quick common pattern that works
    def self.probalistic_clean!
      return unless defined?(::ActiveRecord::Base)

      # Clean up connections to prevent pool exhaustion
      ::ActiveRecord::Base.clear_active_connections!
      GC.start if rand(100) < 5
    end
  end
end
