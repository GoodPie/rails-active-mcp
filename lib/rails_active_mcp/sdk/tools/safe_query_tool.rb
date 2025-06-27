# frozen_string_literal: true

require 'mcp'

module RailsActiveMcp
  module Sdk
    module Tools
      class SafeQueryTool < MCP::Tool
        description 'Execute safe read-only database queries on Rails models'

        input_schema(
          properties: {
            model: {
              type: 'string',
              description: 'Model class name (e.g., "User", "Product")'
            },
            method: {
              type: 'string',
              description: 'Query method (find, where, count, etc.)'
            },
            args: {
              type: 'array',
              description: 'Arguments for the query method'
            },
            limit: {
              type: 'integer',
              description: 'Limit results (default: 100)'
            }
          },
          required: %w[model method]
        )

        annotations(
          title: 'Safe Query Executor',
          destructive_hint: false,
          read_only_hint: true,
          idempotent_hint: true,
          open_world_hint: false
        )

        def self.call(model:, method:, server_context:, args: [], limit: 100)
          config = RailsActiveMcp.config

          executor = RailsActiveMcp::ConsoleExecutor.new(config)

          result = executor.execute_safe_query(
            model: model,
            method: method,
            args: args,
            limit: limit
          )

          if result[:success]
            output = []
            output << "Query: #{model}.#{method}(#{args.join(', ')})"
            output << "Count: #{result[:count]}" if result[:count]
            output << "Result: #{result[:result].inspect}"

            MCP::Tool::Response.new([
                                      { type: 'text', text: output.join("\n") }
                                    ])
          else
            error_response(result[:error])
          end
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
