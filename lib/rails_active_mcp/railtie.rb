# frozen_string_literal: true

module RailsActiveMcp
  class Railtie < ::Rails::Railtie
    railtie_name :rails_active_mcp

    # Add rake tasks
    rake_tasks do
      load 'rails_active_mcp/tasks.rake'
    end

    # Add generators
    generators do
      require 'rails_active_mcp/generators/install_generator'
    end

    # Console hook for easier access
    console do
      RailsActiveMcp.configure unless RailsActiveMcp.configuration

      # Add convenience methods to console
      Rails::ConsoleMethods.include(RailsActiveMcp::ConsoleMethods) if defined?(Rails::ConsoleMethods)
    end

    # Configure logging
    initializer 'rails_active_mcp.logger' do
      RailsActiveMcp.logger = Rails.logger if defined?(Rails.logger)
    end
  end

  # Console convenience methods
  module ConsoleMethods
    def mcp_execute(code, **options)
      RailsActiveMcp.execute(code, **options)
    end

    def mcp_safe?(code)
      RailsActiveMcp.safe?(code)
    end

    def mcp_config
      RailsActiveMcp.config
    end
  end
end
