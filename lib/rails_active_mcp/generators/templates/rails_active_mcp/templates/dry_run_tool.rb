class RailsActiveMcpDryRunTool < ApplicationMCPTool
  tool_name "dry_run"
  description "Analyze Ruby code for safety without executing it"

  property :code, type: "string", description: 'Ruby code to analyze for safety', required: true

  def perform
    return render_disabled_error unless rails_active_mcp_enabled?

    code = properties[:code]
    executor = RailsActiveMcp::ConsoleExecutor.new(RailsActiveMcp.config)
    analysis = executor.dry_run(code)

    output = []
    output << "Code: #{analysis[:code]}"
    output << "Safe: #{analysis[:safety_analysis][:safe] ? 'Yes' : 'No'}"
    output << "Read-only: #{analysis[:safety_analysis][:read_only] ? 'Yes' : 'No'}"
    output << "Risk level: #{analysis[:estimated_risk]}"
    output << "Summary: #{analysis[:safety_analysis][:summary]}"

    if analysis[:safety_analysis][:violations].any?
      output << "\nViolations:"
      analysis[:safety_analysis][:violations].each do |violation|
        output << "  - #{violation[:description]} (#{violation[:severity]})"
      end
    end

    if analysis[:recommendations].any?
      output << "\nRecommendations:"
      analysis[:recommendations].each do |rec|
        output << "  - #{rec}"
      end
    end

    render(text: output.join("\n"))
  end
end