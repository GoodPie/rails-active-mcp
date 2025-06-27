# frozen_string_literal: true

require 'singleton'

module RailsActiveMcp
  class ToolRegistry
    include Singleton

    def initialize
      @tools = {}
      discover_tools
    end

    attr_reader :tools

    def register_tool(name, description, input_schema, annotations = {}, &handler)
      @tools[name] = {
        name: name,
        description: description,
        input_schema: input_schema,
        annotations: annotations,
        handler: handler
      }
    end

    def get_tool(name)
      @tools[name]
    end

    def tool_names
      @tools.keys
    end

    def tools_list
      @tools.values.map do |tool|
        tool_def = {
          name: tool[:name],
          description: tool[:description],
          inputSchema: tool[:input_schema]
        }

        # Add annotations if present
        tool_def[:annotations] = tool[:annotations] if tool[:annotations] && !tool[:annotations].empty?

        tool_def
      end
    end

    def call_tool(name, arguments)
      tool = @tools[name]
      return nil unless tool

      tool[:handler].call(arguments)
    end

    private

    def discover_tools
      # Register all known ApplicationMCPTool subclasses
      tool_classes = [
        RailsActiveMcp::Tools::ConsoleExecuteTool,
        RailsActiveMcp::Tools::ModelInfoTool,
        RailsActiveMcp::Tools::SafeQueryTool,
        RailsActiveMcp::Tools::DryRunTool
      ]

      tool_classes.each do |tool_class|
        register_application_mcp_tool(tool_class)
      end
    end

    def register_application_mcp_tool(tool_class)
      # Register the tool with a handler that creates and calls the tool instance
      register_tool(
        tool_class.tool_name,
        tool_class.description,
        tool_class.input_schema,
        tool_class.annotations
      ) do |arguments|
        # Create a new instance for each call to ensure clean state
        instance = tool_class.new

        # Set the properties from the arguments
        instance.properties = arguments.transform_keys(&:to_sym)

        # Call the perform method and handle the response
        result = instance.perform

        # Convert the response to the expected format
        format_tool_response(result)
      end
    end

    def format_tool_response(response)
      case response[:type] || (response.key?(:error) ? :error : :text)
      when :text
        response[:text] || response[:content]
      when :error
        "Error: #{Array(response[:error]).join(', ')}"
      else
        response.to_s
      end
    end
  end
end
