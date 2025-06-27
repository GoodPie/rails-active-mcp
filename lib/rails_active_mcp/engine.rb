# frozen_string_literal: true

module RailsActiveMcp
  class Engine < ::Rails::Engine
    isolate_namespace RailsActiveMcp

    config.rails_active_mcp = ActiveSupport::OrderedOptions.new

    # Ensure configuration is available very early (from Railtie)
    initializer 'rails_active_mcp.early_configuration', before: :load_config_initializers do
      RailsActiveMcp.configure unless RailsActiveMcp.configuration
    end

    # Configure logging - consolidated from Railtie with Rails 7.1 compatibility
    initializer 'rails_active_mcp.logger', after: :initialize_logger, before: :set_clear_dependencies_hook do
      # Only set logger if Rails logger is available and responds to logging methods
      RailsActiveMcp.logger = if defined?(Rails.logger) && Rails.logger.respond_to?(:info)
                                # Check if Rails logger is using semantic logger or other custom loggers
                                if Rails.logger.class.name.include?('SemanticLogger')
                                  # For semantic logger, we need to create a tagged logger
                                  Rails.logger.tagged('RailsActiveMcp')
                                else
                                  # For standard Rails logger, use it directly
                                  Rails.logger
                                end
                              else
                                # Fallback to our own logger if Rails logger is not available
                                # This should not happen in normal Rails apps but provides safety
                                Logger.new(STDERR).tap do |logger|
                                  logger.level = Rails.env.production? ? Logger::WARN : Logger::INFO
                                  logger.formatter = proc do |severity, datetime, progname, msg|
                                    "[#{datetime}] #{severity} -- RailsActiveMcp: #{msg}\n"
                                  end
                                end
                              end

      # Log that the logger has been initialized
      RailsActiveMcp.logger.info "Rails Active MCP logger initialized (#{RailsActiveMcp.logger.class.name})"
    end

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

    # Add rake tasks (consolidated from Railtie)
    rake_tasks do
      load 'rails_active_mcp/tasks.rake'
    end

    # Add generators (consolidated from Railtie)
    generators do
      # Generators are auto-discovered from lib/generators following Rails conventions
    end

    # Console hook for easier access (consolidated from Railtie)
    console do
      # Add convenience methods to console
      Rails::ConsoleMethods.include(RailsActiveMcp::ConsoleMethods) if defined?(Rails::ConsoleMethods)
    end
  end

  # Console convenience methods (moved from Railtie)
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
