# frozen_string_literal: true

module RailsActiveMcp
  class Engine < ::Rails::Engine
    isolate_namespace RailsActiveMcp

    config.rails_active_mcp = ActiveSupport::OrderedOptions.new

    # Add generators configuration
    config.generators do |g|
      g.test_framework :rspec, fixture: false
      g.assets false
      g.helper false
    end

    # Define routes for the engine
    routes do
      # Main MCP endpoint for HTTP clients
      post '/', to: 'mcp#handle'
      post '/messages', to: 'mcp#handle'

      # SSE endpoint for better MCP client compatibility
      get '/sse', to: 'mcp#sse'

      # Health check endpoint
      get '/health', to: 'mcp#health'

      # Root redirect
      root to: 'mcp#info'
    end

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

    # Add our tools directory to the load path
    config.autoload_paths << root.join('lib', 'rails_active_mcp', 'tools')

    # Ensure our tools are eager loaded in production
    config.eager_load_paths << root.join('lib', 'rails_active_mcp', 'tools')

    # Add rake tasks
    rake_tasks do
      load 'rails_active_mcp/tasks.rake'
    end

    # Console hook for easier access
    console do
      # Add convenience methods to console
      Rails::ConsoleMethods.include(RailsActiveMcp::ConsoleMethods) if defined?(Rails::ConsoleMethods)
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
