# frozen_string_literal: true

require 'mcp'

module RailsActiveMcp
  module Sdk
    module Tools
      class ConsoleExecuteTool < MCP::Tool
        description 'Execute Ruby code in Rails console with safety checks'

        input_schema(
          properties: {
            code: {
              type: 'string',
              description: 'Ruby code to execute in Rails console'
            },
            safe_mode: {
              type: 'boolean',
              description: 'Enable safety checks (default: true)'
            },
            timeout: {
              type: 'integer',
              description: 'Timeout in seconds (default: 30)'
            },
            capture_output: {
              type: 'boolean',
              description: 'Capture console output (default: true)'
            }
          },
          required: ['code']
        )

        annotations(
          title: 'Rails Console Executor',
          destructive_hint: true,
          read_only_hint: false,
          idempotent_hint: false,
          open_world_hint: false
        )

        def self.call(code:, safe_mode: true, timeout: 30, capture_output: true)
          config = RailsActiveMcp.config

          # Check if Rails Active MCP is enabled
          return error_response('Rails Active MCP is disabled') unless config.enabled

          # Create executor with config
          executor = RailsActiveMcp::ConsoleExecutor.new(config)

          begin
            result = executor.execute(
              code,
              timeout: timeout,
              safe_mode: safe_mode,
              capture_output: capture_output
            )

            if result[:success]
              MCP::Tool::Response.new([
                                        { type: 'text', text: format_success_result(result) }
                                      ])
            else
              MCP::Tool::Response.new([
                                        { type: 'text', text: format_error_result(result) }
                                      ])
            end
          rescue RailsActiveMcp::SafetyError => e
            error_response("Safety check failed: #{e.message}")
          rescue RailsActiveMcp::TimeoutError => e
            error_response("Execution timed out: #{e.message}")
          rescue StandardError => e
            error_response("Execution failed: #{e.message}")
          end
        end

        private

        def self.format_success_result(result)
          output = []
          output << "Code: #{result[:code]}"
          output << "Result: #{result[:return_value_string] || result[:return_value]}"

          output << "Output: #{result[:output]}" if result[:output].present?

          output << "Execution time: #{result[:execution_time]}s" if result[:execution_time]

          output << "Note: #{result[:note]}" if result[:note]

          output.join("\n")
        end

        def self.format_error_result(result)
          error_msg = "Error: #{result[:error]}"
          error_msg += " (#{result[:error_class]})" if result[:error_class]
          error_msg
        end

        def self.error_response(message)
          MCP::Tool::Response.new([
                                    { type: 'text', text: message }
                                  ])
        end
      end
    end
  end
end
