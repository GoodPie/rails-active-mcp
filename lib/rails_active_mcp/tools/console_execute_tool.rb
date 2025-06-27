module RailsActiveMcp
  module Tools
    class ConsoleExecuteTool < ApplicationMCPTool
      tool_name 'console_execute'
      description 'Execute Ruby code in Rails console with safety checks'

      property :code, type: 'string', description: 'Ruby code to execute in Rails console', required: true
      property :safe_mode, type: 'boolean', description: 'Enable safety checks (default: true)', required: false
      property :timeout, type: 'integer', description: 'Timeout in seconds (default: 30)', required: false
      property :capture_output, type: 'boolean', description: 'Capture console output (default: true)', required: false

      def perform
        code = properties[:code]
        safe_mode = properties[:safe_mode]
        timeout = properties[:timeout]
        capture_output = properties.fetch(:capture_output, true)

        return render(error: 'Rails Active MCP is disabled') unless RailsActiveMcp.config.enabled

        executor = RailsActiveMcp::ConsoleExecutor.new(RailsActiveMcp.config)

        begin
          result = executor.execute(
            code,
            timeout: timeout,
            safe_mode: safe_mode,
            capture_output: capture_output
          )

          if result[:success]
            render(text: format_success_result(result))
          else
            render(error: [format_error_result(result)])
          end
        rescue RailsActiveMcp::SafetyError => e
          render(error: ["Safety check failed: #{e.message}"])
        rescue RailsActiveMcp::TimeoutError => e
          render(error: ["Execution timed out: #{e.message}"])
        rescue StandardError => e
          render(error: ["Execution failed: #{e.message}"])
        end
      end

      private

      def format_success_result(result)
        output = []
        output << "Code: #{result[:code]}"
        output << "Result: #{result[:return_value_string] || result[:return_value]}"
        output << "Output: #{result[:output]}" if result[:output].present?
        output << "Execution time: #{result[:execution_time]}s" if result[:execution_time]
        output << "Note: #{result[:note]}" if result[:note]
        output.join("\n")
      end

      def format_error_result(result)
        "Error: #{result[:error]} (#{result[:error_class]})"
      end
    end
  end
end
