# frozen_string_literal: true

require 'mcp'

# Require all SDK tools
require_relative 'tools/console_execute_tool'
require_relative 'tools/model_info_tool'
require_relative 'tools/safe_query_tool'
require_relative 'tools/dry_run_tool'

module RailsActiveMcp
  module Sdk
    class Server
      attr_reader :mcp_server

      def initialize
        # Configure MCP first
        configure_mcp

        # Create the MCP server with our tools
        @mcp_server = MCP::Server.new(
          name: 'rails-active-mcp',
          version: RailsActiveMcp::VERSION,
          tools: discover_tools,
          server_context: server_context
        )

        # Set up server handlers
        setup_server_handlers
      end

      def run_stdio
        require 'mcp/transports/stdio'
        transport = MCP::Transports::StdioTransport.new(@mcp_server)
        transport.open
      end

      def run_http(port: 3001)
        # HTTP transport might not be available in the SDK yet
        # For now, fall back to a basic implementation or error
        raise NotImplementedError, 'HTTP transport not yet implemented with official MCP SDK'
      end

      private

      def discover_tools
        [
          RailsActiveMcp::Sdk::Tools::ConsoleExecuteTool,
          RailsActiveMcp::Sdk::Tools::ModelInfoTool,
          RailsActiveMcp::Sdk::Tools::SafeQueryTool,
          RailsActiveMcp::Sdk::Tools::DryRunTool
        ]
      end

      def configure_mcp
        # Configure MCP SDK with Rails-specific handlers
        MCP.configure do |config|
          config.exception_reporter = method(:handle_rails_exception)
          config.instrumentation_callback = method(:log_mcp_calls)
        end
      end

      def setup_server_handlers
        # Set up resource read handler (for future use)
        @mcp_server.resources_read_handler do |params|
          [
            {
              uri: params[:uri],
              mimeType: 'text/plain',
              text: "Rails Active MCP Resource: #{params[:uri]}"
            }
          ]
        end
      end

      def handle_rails_exception(exception, context)
        RailsActiveMcp.logger.error "MCP Error: #{exception.message}"
        RailsActiveMcp.logger.error exception.backtrace.join("\n") if ENV['RAILS_MCP_DEBUG'] == '1'

        # Log context for debugging
        return unless context && ENV['RAILS_MCP_DEBUG'] == '1'

        RailsActiveMcp.logger.debug "MCP Context: #{context.inspect}"
      end

      def log_mcp_calls(data)
        duration_ms = (data[:duration] * 1000).round(2)

        log_message = "MCP #{data[:method]}"
        log_message += " [#{data[:tool_name]}]" if data[:tool_name]
        log_message += " (#{duration_ms}ms)"

        RailsActiveMcp.logger.info log_message

        # Log errors separately
        return unless data[:error]

        RailsActiveMcp.logger.error "MCP Error: #{data[:error]}"
      end

      def server_context
        {
          rails_env: defined?(Rails) ? Rails.env : 'unknown',
          rails_root: defined?(Rails) && Rails.respond_to?(:root) ? Rails.root.to_s : Dir.pwd,
          config: RailsActiveMcp.config,
          gem_version: RailsActiveMcp::VERSION
        }
      end
    end
  end
end
