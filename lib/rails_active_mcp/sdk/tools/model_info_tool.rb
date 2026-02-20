# frozen_string_literal: true

require 'mcp'

module RailsActiveMcp
  module Sdk
    module Tools
      class ModelInfoTool < MCP::Tool
        description 'Get information about Rails models including schema and associations'

        input_schema(
          properties: {
            model: {
              type: 'string',
              description: 'Model class name'
            },
            include_schema: {
              type: 'boolean',
              description: 'Include database schema information'
            },
            include_associations: {
              type: 'boolean',
              description: 'Include model associations'
            },
            include_validations: {
              type: 'boolean',
              description: 'Include model validations'
            }
          },
          required: ['model']
        )

        annotations(
          title: 'Rails Model Inspector',
          destructive_hint: false,
          read_only_hint: true,
          idempotent_hint: true,
          open_world_hint: false
        )

        def self.call(model:, server_context:, include_schema: true, include_associations: true,
                      include_validations: true)
          config = RailsActiveMcp.config
          executor = RailsActiveMcp::ConsoleExecutor.new(config)
          result = executor.get_model_info(model)

          return error_response(result[:error]) unless result[:success]

          output = []
          output << "Model: #{result[:model_name]}"
          output << "Table: #{result[:table_name]}"
          output << "Primary Key: #{result[:primary_key]}"

          if include_schema
            output << "\nSchema:"
            result[:columns].each do |column|
              output << "  #{column[:name]}: #{column[:type]}"
              output << "    - Primary: #{column[:primary]}"
            end
          end

          if include_associations
            output << "\nAssociations:"
            result[:associations].each do |assoc|
              output << "  #{assoc[:name]}: #{assoc[:type]} -> #{assoc[:class_name]}"
            end
          end

          if include_validations && result[:validators]&.any?
            output << "\nValidations:"
            validations = {}
            result[:validators].each do |validator|
              validator[:attributes].each do |attribute|
                validations[attribute] ||= []
                validations[attribute] << validator[:type].to_s.split('::').last
              end
            end
            validations.each do |attr, validators|
              output << "  #{attr}: #{validators.join(', ')}"
            end
          end

          MCP::Tool::Response.new([
                                    { type: 'text', text: output.join("\n") }
                                  ])
        end

        def self.error_response(message)
          MCP::Tool::Response.new(
            [{ type: 'text', text: message }],
            is_error: true
          )
        end
      end
    end
  end
end
