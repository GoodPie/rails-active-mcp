# frozen_string_literal: true

require 'mcp'

module RailsActiveMcp
  module Sdk
    module Tools
      class SafeQueryTool < MCP::Tool
        description 'Execute safe, read-only database queries'

        input_schema(
          properties: {
            model: {
              type: 'string',
              description: 'Rails model name'
            },
            query: {
              type: 'string',
              description: "Query method chain (e.g., 'where(active: true).count')"
            }
          },
          required: %w[model query]
        )

        annotations(
          title: 'Rails Safe Query Executor',
          destructive_hint: false,
          read_only_hint: true,
          idempotent_hint: true,
          open_world_hint: false
        )

        def self.call(model:, query:, server_context:)
          config = server_context[:config]

          return error_response('Rails Active MCP is disabled') unless config.enabled

          # For now, return a placeholder - will implement full logic later
          MCP::Tool::Response.new([
                                    { type: 'text',
                                      text: "Safe Query Tool (SDK) - Model: #{model}, Query: #{query} - Implementation pending" }
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
