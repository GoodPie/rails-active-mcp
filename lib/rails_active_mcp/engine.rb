# frozen_string_literal: true

module RailsActiveMcp
  class Engine < ::Rails::Engine
    isolate_namespace RailsActiveMcp

    config.rails_active_mcp = ActiveSupport::OrderedOptions.new

    # Ensure configuration is available very early
    initializer 'rails_active_mcp.early_configuration', before: :load_config_initializers do
      RailsActiveMcp.configure unless RailsActiveMcp.configuration
    end

    # Configure logging with Rails 7.1+ compatibility
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
                                Logger.new($stderr).tap do |logger|
                                  logger.level = Rails.env.production? ? Logger::WARN : Logger::INFO
                                  logger.formatter = proc do |severity, datetime, _progname, msg|
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

    initializer 'rails_active_mcp.configure' do |app|
      # Load configuration from Rails config if present
      if app.config.respond_to?(:rails_active_mcp)
        RailsActiveMcp.configure do |config|
          app.config.rails_active_mcp.each do |key, value|
            config.public_send("#{key}=", value) if config.respond_to?("#{key}=")
          end
        end
      end

      # Validate configuration
      RailsActiveMcp.config.valid?
    end

    # Add our SDK tools directory to the load path
    config.autoload_paths << root.join('lib', 'rails_active_mcp', 'sdk', 'tools')

    # Ensure our SDK tools are eager loaded in production
    config.eager_load_paths << root.join('lib', 'rails_active_mcp', 'sdk', 'tools')

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
    def mcp_execute(code, **)
      RailsActiveMcp.execute(code, **)
    end

    def mcp_safe?(code)
      RailsActiveMcp.safe?(code)
    end

    def mcp_config
      RailsActiveMcp.config
    end
  end
end
