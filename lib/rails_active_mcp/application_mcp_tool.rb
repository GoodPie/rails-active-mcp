# frozen_string_literal: true

module RailsActiveMcp
  class ApplicationMCPTool
    attr_accessor :properties

    class << self
      attr_accessor :tool_name, :description, :_properties, :_annotations

      def tool_name(name = nil)
        return @tool_name if name.nil?

        @tool_name = name
      end

      def description(desc = nil)
        return @description if desc.nil?

        @description = desc
      end

      def property(name, type:, description:, required: false, **options)
        @_properties ||= {}
        @_properties[name] = {
          type: type,
          description: description,
          required: required
        }.merge(options)
      end

      def annotation(key, value)
        @_annotations ||= {}
        @_annotations[key] = value
      end

      def input_schema
        return {} unless @_properties

        properties = {}
        required = []

        @_properties.each do |name, config|
          property_def = {
            type: config[:type],
            description: config[:description]
          }

          # Add default value if specified
          property_def[:default] = config[:default] if config.key?(:default)

          properties[name] = property_def
          required << name.to_s if config[:required]
        end

        schema = {
          type: 'object',
          properties: properties
        }
        schema[:required] = required unless required.empty?
        schema
      end

      def annotations
        @_annotations || {}
      end

      private

      def default_annotations
        # Default to empty annotations - let individual tools define their own
        {}
      end
    end

    def initialize
      @properties = {}
    end

    def perform
      raise NotImplementedError, "#{self.class} must implement #perform"
    end

    protected

    def render(text: nil, error: nil)
      if error
        { type: :error, error: error }
      else
        { type: :text, text: text }
      end
    end
  end
end
