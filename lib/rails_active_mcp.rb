# frozen_string_literal: true

require 'logger'
require_relative 'rails_active_mcp/version'
require_relative 'rails_active_mcp/configuration'
require_relative 'rails_active_mcp/safety_checker'
require_relative 'rails_active_mcp/console_executor'
require_relative 'rails_active_mcp/garbage_collection_utils'

# Load SDK server
require_relative 'rails_active_mcp/sdk/server'

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
    def execute(code, **)
      ConsoleExecutor.new(config).execute(code, **)
    end

    # Logger accessor - configured by engine or defaults to stderr
    def logger
      @logger ||= Logger.new($stderr).tap do |logger|
        logger.level = Logger::INFO
        logger.formatter = proc do |severity, datetime, _progname, msg|
          "[#{datetime}] #{severity} -- RailsActiveMcp: #{msg}\n"
        end
      end
    end

    attr_writer :logger
  end
end
