# frozen_string_literal: true

module RailsActiveMcp
  class Engine < ::Rails::Engine
    isolate_namespace RailsActiveMcp

    config.rails_active_mcp = ActiveSupport::OrderedOptions.new

    initializer 'rails_active_mcp.configure' do |app|
      # Load configuration from Rails config if present
      if app.config.respond_to?(:rails_active_mcp)
        RailsActiveMcp.configure do |config|
          app.config.rails_active_mcp.each do |key, value|
            config.public_send("#{key}=", value) if config.respond_to?("#{key}=")
          end
        end
      end

      # Set default audit file location
      RailsActiveMcp.config.audit_file ||= Rails.root.join('log', 'rails_active_mcp.log')

      # Validate configuration
      RailsActiveMcp.config.validate!
    end

    initializer 'rails_active_mcp.register_tools' do
      # Register MCP tools with ActionMCP if it's available
      if defined?(ActionMCP) && Rails.logger
        # Tools will be auto-discovered from the tools directory
        Rails.logger&.info 'Rails Active MCP tools registered with ActionMCP'
      end
    end

    # Add our tools directory to the load path
    config.autoload_paths << root.join('lib', 'rails_active_mcp', 'tools')

    # Ensure our tools are eager loaded in production
    config.eager_load_paths << root.join('lib', 'rails_active_mcp', 'tools')
  end
end
