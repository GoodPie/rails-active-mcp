# frozen_string_literal: true

require 'mcp'

module RailsActiveMcp
  module Sdk
    module Tools
      class DryRunTool < MCP::Tool
        description 'Analyze Ruby code for safety without executing'

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
          title: 'Rails Code Safety Analyzer',
          destructive_hint: false,
          read_only_hint: true,
          idempotent_hint: true,
          open_world_hint: false
        )

        def self.call(code:, server_context:)
          config = server_context[:config]

          return error_response('Rails Active MCP is disabled') unless config.enabled

          # For now, return a placeholder - will implement full logic later
          MCP::Tool::Response.new([
                                    { type: 'text',
                                      text: "Dry Run Tool (SDK) - Code: #{code} - Implementation pending" }
                                  ])
        end

        private

        def self.error_response(message)
          MCP::Tool::Response.new([
                                    { type: 'text', text: message }
                                  ])
        end
      end
    end
  end
end
