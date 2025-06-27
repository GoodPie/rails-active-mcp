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

          begin
            model_class = model.constantize

            output = []
            output << "Model: #{model}"
            output << "Table: #{model_class.table_name}"
            output << "Primary Key: #{model_class.primary_key}"

            if include_schema
              output << "\nSchema:"
              model_class.columns.each do |column|
                output << "  #{column.name}: #{column.type} (#{column.sql_type})"
                output << "    - Null: #{column.null}"
                output << "    - Default: #{column.default}" if column.default
              end
            end

            if include_associations
              output << "\nAssociations:"
              model_class.reflections.each do |name, reflection|
                output << "  #{name}: #{reflection.class.name.split('::').last} -> #{reflection.class_name}"
              end
            end

            if include_validations
              validations = {}
              model_class.validators.each do |validator|
                validator.attributes.each do |attribute|
                  validations[attribute] ||= []
                  validations[attribute] << validator.class.name.split('::').last
                end
              end

              if validations.any?
                output << "\nValidations:"
                validations.each do |attr, validators|
                  output << "  #{attr}: #{validators.join(', ')}"
                end
              end
            end

            MCP::Tool::Response.new([
                                      { type: 'text', text: output.join("\n") }
                                    ])
          rescue NameError
            error_response("Model '#{model}' not found")
          rescue StandardError => e
            error_response("Error analyzing model: #{e.message}")
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
