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
            },
            include_enums: {
              type: 'boolean',
              description: 'Include enum definitions and their values'
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

        def self.call(model:, server_context:, **)
          new(model:, **).call
        end

        def initialize(model: nil, **options) # rubocop:disable Lint/MissingSuper
          @model = model
          @include_schema = options.fetch(:include_schema, true)
          @include_associations = options.fetch(:include_associations, true)
          @include_validations = options.fetch(:include_validations, true)
          @include_enums = options.fetch(:include_enums, true)
        end

        def call
          config = RailsActiveMcp.config
          executor = RailsActiveMcp::ConsoleExecutor.new(config)
          @result = executor.get_model_info(@model)

          return self.class.error_response(@result[:error]) unless @result[:success]

          @output = []
          @output << "Model: #{@result[:model_name]}"
          @output << "Table: #{@result[:table_name]}"
          @output << "Primary Key: #{@result[:primary_key]}"

          append_schema if @include_schema
          append_associations if @include_associations
          append_validations if @include_validations
          append_enums if @include_enums

          MCP::Tool::Response.new([
                                    { type: 'text', text: @output.join("\n") }
                                  ])
        end

        def self.error_response(message)
          MCP::Tool::Response.new(
            [{ type: 'text', text: message }],
            error: true
          )
        end

        private

        def append_schema
          @output << "\nSchema:"
          @result[:columns].each do |column|
            @output << "  #{column[:name]}: #{column[:type]}"
            @output << "    - Primary: #{column[:primary]}"
          end
        end

        def append_associations
          @output << "\nAssociations:"
          @result[:associations].each do |assoc|
            @output << "  #{assoc[:name]}: #{assoc[:type]} -> #{assoc[:class_name]}"
          end
        end

        def append_validations
          return unless @result[:validators]&.any?

          @output << "\nValidations:"
          validations = {}
          @result[:validators].each do |validator|
            validator[:attributes].each do |attribute|
              validations[attribute] ||= []
              validations[attribute] << validator[:type].to_s.split('::').last
            end
          end
          validations.each do |attr, validators|
            @output << "  #{attr}: #{validators.join(', ')}"
          end
        end

        def append_enums
          return unless @result[:enums]&.any?

          @output << "\nEnums:"
          @result[:enums].each do |attribute, mapping|
            values = mapping.map { |label, db_value| "#{label} (#{db_value})" }.join(', ')
            @output << "  #{attribute}: #{values}"
          end
        end
      end
    end
  end
end
