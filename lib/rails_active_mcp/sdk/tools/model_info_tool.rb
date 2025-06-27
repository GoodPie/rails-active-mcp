# frozen_string_literal: true

require 'mcp'

module RailsActiveMcp
  module Sdk
    module Tools
      class ModelInfoTool < MCP::Tool
        description 'Get detailed information about Rails models'

        input_schema(
          properties: {
            model_name: {
              type: 'string',
              description: 'Name of the Rails model to inspect'
            }
          },
          required: ['model_name']
        )

        annotations(
          title: 'Rails Model Inspector',
          destructive_hint: false,
          read_only_hint: true,
          idempotent_hint: true,
          open_world_hint: false
        )

        def self.call(model_name:, server_context:)
          config = server_context[:config]

          return error_response('Rails Active MCP is disabled') unless config.enabled

          # For now, return a placeholder - will implement full logic later
          MCP::Tool::Response.new([
                                    { type: 'text',
                                      text: "Model Info Tool (SDK) - Model: #{model_name} - Implementation pending" }
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
