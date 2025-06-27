module RailsActiveMcp
  module Tools
    class ModelInfoTool < ApplicationMCPTool
      tool_name 'model_info'
      description 'Get information about Rails models including schema and associations'

      property :model, type: 'string', description: 'Model class name', required: true
      property :include_schema, type: 'boolean', description: 'Include database schema information', required: false
      property :include_associations, type: 'boolean', description: 'Include model associations', required: false
      property :include_validations, type: 'boolean', description: 'Include model validations', required: false

      # MCP annotations for this tool
      annotation :title, 'Rails Model Inspector'
      annotation :readOnlyHint, true
      annotation :destructiveHint, false
      annotation :idempotentHint, true
      annotation :openWorldHint, false

      def perform
        return render(error: 'Rails Active MCP is disabled') unless RailsActiveMcp.config.enabled

        model = properties[:model]
        include_schema = properties.fetch(:include_schema, true)
        include_associations = properties.fetch(:include_associations, true)
        include_validations = properties.fetch(:include_validations, true)

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

          render(text: output.join("\n"))
        rescue NameError
          render(error: ["Model '#{model}' not found"])
        rescue StandardError => e
          render(error: ["Error analyzing model: #{e.message}"])
        end
      end
    end
  end
end
