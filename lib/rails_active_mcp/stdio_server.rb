# frozen_string_literal: true

require 'json'
require 'io/console'
require 'logger'

module RailsActiveMcp
  class StdioServer < JsonRpcServer
    def initialize
      super
      @running = false

      # Ensure all logging goes to stderr, never stdout
      setup_logging
      # Suppress any Rails application logging that might interfere with MCP protocol
      suppress_rails_logging

      log_to_stderr 'Rails Active MCP Server initialized', level: :info
    end

    def start
      @running = true
      log_to_stderr 'Rails Active MCP Server started successfully', level: :info

      # Send initial notification to stderr first, then stdout for MCP
      send_notification('info', 'Rails Active MCP Server started successfully')

      process_requests
    end

    def stop
      @running = false
      log_to_stderr 'Rails Active MCP Server stopped', level: :info
    end

    private

    def setup_logging
      # Configure Rails Active MCP logger to use stderr
      return unless RailsActiveMcp.respond_to?(:logger=)

      stderr_logger = Logger.new($stderr)
      stderr_logger.level = ENV['RAILS_MCP_DEBUG'] == '1' ? Logger::DEBUG : Logger::INFO
      stderr_logger.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime('%Y-%m-%d %H:%M:%S %z')}] [RAILS-MCP] #{severity}: #{msg}\n"
      end
      RailsActiveMcp.logger = stderr_logger
    end

    def suppress_rails_logging
      # Suppress Rails application logging that might interfere with MCP JSON protocol
      return unless defined?(Rails) && Rails.respond_to?(:logger=)
      return if ENV['RAILS_MCP_DEBUG'] == '1'

      # Redirect Rails logger to stderr or null device
      begin
        if defined?(Rails.application) && Rails.application
          # Set Rails logger to use stderr instead of stdout
          rails_logger = Logger.new($stderr)
          rails_logger.level = Logger::ERROR # Only log errors
          rails_logger.formatter = proc do |severity, datetime, progname, msg|
            "[#{datetime.strftime('%Y-%m-%d %H:%M:%S %z')}] [RAILS-APP] #{severity}: #{msg}\n"
          end
          Rails.logger = rails_logger

          # Also suppress ActiveRecord logging if present
          ActiveRecord::Base.logger = rails_logger if defined?(ActiveRecord::Base)
        end
      rescue StandardError => e
        log_to_stderr "Warning: Could not configure Rails logging: #{e.message}", level: :warn
      end
    end

    def process_requests
      while @running
        begin
          line = $stdin.gets
          break if line.nil?

          line = line.strip
          next if line.empty?

          log_to_stderr "Received request: #{line}", level: :debug

          request = JSON.parse(line)
          log_to_stderr "Processing method: #{request['method']}", level: :debug

          # Capture any output that might leak during request processing
          response = capture_stdout_during_request do
            handle_jsonrpc_request(request)
          end

          log_to_stderr "Sending response: #{response.to_json}", level: :debug

          # Only JSON responses go to stdout
          $stdout.puts response.to_json
          $stdout.flush
        rescue JSON::ParserError => e
          log_to_stderr "JSON parse error: #{e.message}", level: :error
          send_error_response(nil, -32_700, 'Parse error')
        rescue StandardError => e
          log_to_stderr "Server error: #{e.message}", level: :error
          log_to_stderr e.backtrace.join("\n"), level: :debug
          send_error_response(nil, -32_603, 'Internal error')
        end
      end
    end

    def capture_stdout_during_request
      # Temporarily capture stdout to prevent any Rails output from leaking
      original_stdout = $stdout
      begin
        $stdout = StringIO.new
        result = yield
        result
      ensure
        $stdout = original_stdout
      end
    end

    def send_notification(level, message)
      notification = {
        jsonrpc: JSONRPC_VERSION,
        method: 'notifications/message',
        params: {
          level: level,
          data: message
        }
      }

      # Notifications go to stdout for MCP protocol
      $stdout.puts notification.to_json
      $stdout.flush
    end

    def send_error_response(id, code, message)
      error_response = jsonrpc_error(id, code, message)

      $stdout.puts error_response.to_json
      $stdout.flush
    end

    def log_to_stderr(message, level: :info)
      return unless ENV['RAILS_MCP_DEBUG'] == '1' || level == :error || level == :info

      timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S %z')
      warn "[#{timestamp}] [RAILS-MCP] #{level.to_s.upcase}: #{message}"
      $stderr.flush
    end
  end
end
