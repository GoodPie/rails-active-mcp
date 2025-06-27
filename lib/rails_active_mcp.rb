# frozen_string_literal: true

require 'logger'
require_relative 'rails_active_mcp/version'
require_relative 'rails_active_mcp/configuration'
require_relative 'rails_active_mcp/safety_checker'
require_relative 'rails_active_mcp/console_executor'
require_relative 'rails_active_mcp/mcp_server'

# Load Engine for Rails integration
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

    # Logger accessor - configured by railtie or defaults to stdout
    attr_accessor :logger

    def logger
      @logger ||= Logger.new(STDOUT).tap do |logger|
        logger.level = Logger::INFO
        logger.formatter = proc do |severity, datetime, progname, msg|
          "[#{datetime}] #{severity} -- RailsActiveMcp: #{msg}\n"
        end
      end
    end
  end
end
