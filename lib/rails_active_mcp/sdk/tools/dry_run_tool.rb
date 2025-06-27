# frozen_string_literal: true

require 'mcp'

module RailsActiveMcp
  module Sdk
    module Tools
      class DryRunTool < MCP::Tool
        description 'Analyze Ruby code for safety without executing it'

        input_schema(
          properties: {
            code: {
              type: 'string',
              description: 'Ruby code to analyze for safety'
            }
          },
          required: ['code']
        )

        annotations(
          title: 'Code Safety Analyzer',
          destructive_hint: false,
          read_only_hint: true,
          idempotent_hint: true,
          open_world_hint: false
        )

        def self.call(code:, server_context:, check_safety: true, analyze_dependencies: true)
          config = RailsActiveMcp.config

          # Create safety checker

          executor = RailsActiveMcp::ConsoleExecutor.new(config)
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

          MCP::Tool::Response.new([
                                    { type: 'text', text: output.join("\n") }
                                  ])
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
