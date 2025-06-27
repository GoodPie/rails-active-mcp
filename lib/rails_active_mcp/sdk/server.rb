# frozen_string_literal: true

require 'mcp'
require 'stringio'
require 'fileutils'

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
        # Store original streams for restoration
        @original_stdout = $stdout
        @original_stderr = $stderr

        # Set up output redirection BEFORE any Rails interaction
        setup_output_redirection

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
        # Ensure output redirection is active for stdio mode
        ensure_output_redirection_for_stdio

        require 'mcp/transports/stdio'
        transport = MCP::Transports::StdioTransport.new(@mcp_server)
        transport.open
      rescue StandardError => e
        # Log to stderr (which is redirected to file) and re-raise
        warn "[#{Time.now}] [RAILS-MCP] FATAL: SDK Server crashed: #{e.message}"
        warn "[#{Time.now}] [RAILS-MCP] FATAL: #{e.backtrace.join("\n")}"
        raise
      ensure
        restore_output_streams
      end

      def run_http(port: 3001)
        # HTTP transport might not be available in the SDK yet
        # For now, fall back to a basic implementation or error
        raise NotImplementedError, 'HTTP transport not yet implemented with official MCP SDK'
      end

      private

      def setup_output_redirection
        # Skip redirection if in debug mode
        return if ENV['RAILS_MCP_DEBUG'] == '1'

        # Create log directory
        log_dir = File.join(Dir.pwd, 'log')
        FileUtils.mkdir_p(log_dir) unless Dir.exist?(log_dir)

        # Redirect stderr to log file
        stderr_log = File.join(log_dir, 'rails_mcp_stderr.log')
        @stderr_file = File.open(stderr_log, 'a')
        @stderr_file.sync = true
        $stderr = @stderr_file

        # Capture stdout during initialization to prevent interference
        @stdout_buffer = StringIO.new
        $stdout = @stdout_buffer

        # Log redirection setup
        warn "[#{Time.now}] [RAILS-MCP] INFO: Output redirection enabled. stderr -> #{stderr_log}"
      end

      def ensure_output_redirection_for_stdio
        # Skip if in debug mode
        return if ENV['RAILS_MCP_DEBUG'] == '1'

        # Check if anything was captured during initialization
        if @stdout_buffer && !@stdout_buffer.string.empty?
          captured = @stdout_buffer.string
          warn "[#{Time.now}] [RAILS-MCP] WARNING: Captured stdout during initialization: #{captured.inspect}"
        end

        # Restore original stdout for MCP communication, keep stderr redirected
        $stdout = @original_stdout
        warn "[#{Time.now}] [RAILS-MCP] INFO: stdout restored for MCP communication, stderr remains redirected"
      end

      def restore_output_streams
        return if ENV['RAILS_MCP_DEBUG'] == '1'

        begin
          $stdout = @original_stdout if @original_stdout
          $stderr = @original_stderr if @original_stderr
          @stderr_file&.close
        rescue StandardError => e
          # Best effort cleanup
          warn "Failed to restore output streams: #{e.message}" if @original_stderr
        end
      end

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
        # Use stderr which is redirected to log file
        warn "[#{Time.now}] [RAILS-MCP] ERROR: MCP Exception: #{exception.message}"
        warn "[#{Time.now}] [RAILS-MCP] ERROR: #{exception.backtrace.join("\n")}" if ENV['RAILS_MCP_DEBUG'] == '1'

        # Log context for debugging
        return unless context && ENV['RAILS_MCP_DEBUG'] == '1'

        warn "[#{Time.now}] [RAILS-MCP] DEBUG: MCP Context: #{context.inspect}"
      end

      def log_mcp_calls(data)
        return unless ENV['RAILS_MCP_DEBUG'] == '1'

        duration_ms = (data[:duration] * 1000).round(2)

        log_message = "MCP #{data[:method]}"
        log_message += " [#{data[:tool_name]}]" if data[:tool_name]
        log_message += " (#{duration_ms}ms)"

        warn "[#{Time.now}] [RAILS-MCP] DEBUG: #{log_message}"

        # Log errors separately
        return unless data[:error]

        warn "[#{Time.now}] [RAILS-MCP] ERROR: MCP Call Error: #{data[:error]}"
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
