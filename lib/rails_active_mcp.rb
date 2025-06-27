# frozen_string_literal: true

require 'logger'
require_relative 'rails_active_mcp/version'
require_relative 'rails_active_mcp/configuration'
require_relative 'rails_active_mcp/safety_checker'
require_relative 'rails_active_mcp/console_executor'
require_relative 'rails_active_mcp/application_mcp_tool'

# Load all tool classes
require_relative 'rails_active_mcp/tools/console_execute_tool'
require_relative 'rails_active_mcp/tools/model_info_tool'
require_relative 'rails_active_mcp/tools/safe_query_tool'
require_relative 'rails_active_mcp/tools/dry_run_tool'

require_relative 'rails_active_mcp/tool_registry'
require_relative 'rails_active_mcp/mcp_server'

# Load Engine for Rails integration (consolidated from Railtie)
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

    # Logger accessor - configured by railtie or defaults to stderr
    attr_accessor :logger

    # Logger accessor - configured by railtie or defaults to stderr
    def logger
      @logger ||= Logger.new($stderr).tap do |logger|
        logger.level = Logger::INFO
        logger.formatter = proc do |severity, datetime, progname, msg|
          "[#{datetime}] #{severity} -- RailsActiveMcp: #{msg}\n"
        end
      end
    end
  end
end
