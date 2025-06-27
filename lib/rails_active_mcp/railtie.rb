# frozen_string_literal: true

module RailsActiveMcp
  class Railtie < ::Rails::Railtie
    railtie_name :rails_active_mcp

    # Ensure configuration is available very early
    config.before_initialize do
      RailsActiveMcp.configure unless RailsActiveMcp.configuration
    end

    # Add rake tasks
    rake_tasks do
      load 'rails_active_mcp/tasks.rake'
    end

    # Add generators
    generators do
      # Generators are auto-discovered from lib/generators following Rails conventions
    end

    # Console hook for easier access
    console do
      # Add convenience methods to console
      Rails::ConsoleMethods.include(RailsActiveMcp::ConsoleMethods) if defined?(Rails::ConsoleMethods)
    end

    # Configure logging - Fixed for Rails 7.1 compatibility
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
                                Logger.new(STDOUT).tap do |logger|
                                  logger.level = Rails.env.production? ? Logger::WARN : Logger::INFO
                                  logger.formatter = proc do |severity, datetime, progname, msg|
                                    "[#{datetime}] #{severity} -- RailsActiveMcp: #{msg}\n"
                                  end
                                end
                              end

      # Log that the logger has been initialized
      RailsActiveMcp.logger.info "Rails Active MCP logger initialized (#{RailsActiveMcp.logger.class.name})"
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
