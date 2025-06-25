class RailsActiveMcpConsoleExecuteTool < ApplicationMCPTool
  tool_name "console_execute"
  description "Execute Ruby code in Rails console with safety checks"

  property :code, type: "string", description: 'Ruby code to execute in Rails console', required: true
  property :safe_mode, type: "boolean", description: 'Enable safety checks (default: true)', required: false
  property :timeout, type: "integer", description: 'Timeout in seconds (default: 30)', required: false
  property :capture_output, type: "boolean", description: 'Capture console output (default: true)', required: false

  def perform
    return render_disabled_error unless rails_active_mcp_enabled?

    code = properties[:code]
    safe_mode = properties[:safe_mode]
    timeout = properties[:timeout]
    capture_output = properties.fetch(:capture_output, true)

    executor = RailsActiveMcp::ConsoleExecutor.new(RailsActiveMcp.config)

    begin
      result = executor.execute(
        code,
        timeout: timeout,
        safe_mode: safe_mode,
        capture_output: capture_output
      )

      if result[:success]
        output = []
        output << "Code: #{result[:code]}"
        output << "Result: #{result[:return_value_string] || result[:return_value]}"
        output << "Output: #{result[:output]}" if result[:output].present?
        output << "Execution time: #{result[:execution_time]}s" if result[:execution_time]
        output << "Note: #{result[:note]}" if result[:note]
        render(text: output.join("\n"))
      else
        render(error: ["Error: #{result[:error]} (#{result[:error_class]})"])
      end
    rescue RailsActiveMcp::SafetyError => e
      render(error: ["Safety check failed: #{e.message}"])
    rescue RailsActiveMcp::TimeoutError => e
      render(error: ["Execution timed out: #{e.message}"])
    rescue => e
      render(error: ["Execution failed: #{e.message}"])
    end
  end
end
