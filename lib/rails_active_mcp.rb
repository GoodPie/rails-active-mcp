# frozen_string_literal: true

require 'logger'
require_relative 'rails_active_mcp/version'
require_relative 'rails_active_mcp/configuration'
require_relative 'rails_active_mcp/safety_checker'
require_relative 'rails_active_mcp/console_executor'
require_relative 'rails_active_mcp/mcp_server'
require_relative 'rails_active_mcp/engine' if defined?(Rails)


module RailsActiveMcp
  class Error < StandardError; end

  class SafetyError < Error; end

  class ExecutionError < Error; end

  class TimeoutError < Error; end

  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
      configuration
    end

    def config
      configuration || configure
    end

    # Quick access to safety checker
    def safe?(code)
      SafetyChecker.new(config).safe?(code)
    end

    # Quick execution method
    def execute(code, **options)
      ConsoleExecutor.new(config).execute(code, **options)
    end

    # Access to MCP server instance
    def server
      @server ||= McpServer.new
    end

    # Add logger accessor
    attr_accessor :logger

    def logger
      @logger ||= defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger ? Rails.logger : Logger.new(STDOUT)
    end
  end
end

# Auto-configure for Rails
require_relative 'rails_active_mcp/railtie' if defined?(Rails)
