# frozen_string_literal: true

require 'json'
require 'rack'

module RailsActiveMcp
  class McpServer
    JSONRPC_VERSION = '2.0'
    MCP_VERSION = '2025-06-18'

    def initialize(app = nil)
      @app = app
      @tools = {}
      @resources = {}
      register_default_tools
    end

    def call(env)
      request = Rack::Request.new(env)

      return [405, {}, ['Method Not Allowed']] unless request.post?
      return [400, {}, ['Invalid Content-Type']] unless json_request?(request)

      begin
        body = request.body.read
        data = JSON.parse(body)
        response = handle_jsonrpc_request(data)

        [200, { 'Content-Type' => 'application/json' }, [response.to_json]]
      rescue JSON::ParserError
        error_response(400, 'Invalid JSON')
      rescue StandardError => e
        RailsActiveMcp.logger.error "MCP Server Error: #{e.message}"
        error_response(500, 'Internal Server Error')
      end
    end

    private

    def json_request?(request)
      request.content_type&.include?('application/json')
    end

    def handle_jsonrpc_request(data)
      case data['method']
      when 'initialize'
        handle_initialize(data)
      when 'tools/list'
        handle_tools_list(data)
      when 'tools/call'
        handle_tools_call(data)
      when 'resources/list'
        handle_resources_list(data)
      when 'resources/read'
        handle_resources_read(data)
      else
        jsonrpc_error(data['id'], -32_601, 'Method not found')
      end
    end

    def handle_initialize(data)
      {
        jsonrpc: JSONRPC_VERSION,
        id: data['id'],
        result: {
          protocolVersion: MCP_VERSION,
          capabilities: {
            tools: {
              list: true,
              call: true
            },
            resources: {
              read: true,
              list: true
            }
          },
          serverInfo: {
            name: 'rails-active-mcp',
            version: RailsActiveMcp::VERSION
          }
        }
      }
    end

    def handle_tools_list(data)
      tools_array = @tools.values.map do |tool|
        tool_def = {
          name: tool[:name],
          description: tool[:description],
          inputSchema: tool[:input_schema]
        }

        # Add annotations if present
        tool_def[:annotations] = tool[:annotations] if tool[:annotations] && !tool[:annotations].empty?

        tool_def
      end

      {
        jsonrpc: JSONRPC_VERSION,
        id: data['id'],
        result: { tools: tools_array }
      }
    end

    def handle_tools_call(data)
      tool_name = data.dig('params', 'name')
      arguments = data.dig('params', 'arguments') || {}

      tool = @tools[tool_name]
      return jsonrpc_error(data['id'], -32_602, "Tool '#{tool_name}' not found") unless tool

      begin
        result = tool[:handler].call(arguments)
        {
          jsonrpc: JSONRPC_VERSION,
          id: data['id'],
          result: { content: [{ type: 'text', text: result.to_s }] }
        }
      rescue StandardError => e
        jsonrpc_error(data['id'], -32_603, "Tool execution failed: #{e.message}")
      end
    end

    def handle_resources_list(data)
      {
        jsonrpc: JSONRPC_VERSION,
        id: data['id'],
        result: { resources: [] }
      }
    end

    def handle_resources_read(data)
      {
        jsonrpc: JSONRPC_VERSION,
        id: data['id'],
        result: { contents: [] }
      }
    end

    def register_tool(name, description, input_schema, annotations = {}, &handler)
      @tools[name] = {
        name: name,
        description: description,
        input_schema: input_schema,
        annotations: annotations,
        handler: handler
      }
    end

    def register_default_tools
      register_tool(
        'rails_console_execute',
        'Execute Ruby code in Rails console context',
        {
          type: 'object',
          properties: {
            code: { type: 'string', description: 'Ruby code to execute' },
            timeout: { type: 'number', description: 'Timeout in seconds', default: 30 },
            safe_mode: { type: 'boolean', description: 'Enable safety checks', default: true },
            capture_output: { type: 'boolean', description: 'Capture console output', default: true }
          },
          required: ['code']
        },
        # Add MCP tool annotations
        {
          title: 'Rails Console Executor',
          readOnlyHint: false,
          destructiveHint: true,
          idempotentHint: false,
          openWorldHint: false
        }
      ) do |args|
        execute_console_code(args)
      end

      register_tool(
        'rails_model_info',
        'Get information about Rails models',
        {
          type: 'object',
          properties: {
            model_name: { type: 'string', description: 'Name of the model to inspect' }
          },
          required: ['model_name']
        },
        # Safe read-only tool
        {
          title: 'Rails Model Inspector',
          readOnlyHint: true,
          destructiveHint: false,
          idempotentHint: true,
          openWorldHint: false
        }
      ) do |args|
        get_model_info(args['model_name'])
      end

      register_tool(
        'rails_safe_query',
        'Execute safe read-only database queries',
        {
          type: 'object',
          properties: {
            query: { type: 'string', description: 'Safe query to execute' },
            model: { type: 'string', description: 'Model class name' }
          },
          required: %w[query model]
        },
        # Safe read-only query tool
        {
          title: 'Rails Safe Query Executor',
          readOnlyHint: true,
          destructiveHint: false,
          idempotentHint: true,
          openWorldHint: false
        }
      ) do |args|
        execute_safe_query(args)
      end

      register_tool(
        'rails_dry_run',
        'Analyze Ruby code safety without execution',
        {
          type: 'object',
          properties: {
            code: { type: 'string', description: 'Ruby code to analyze' }
          },
          required: ['code']
        },
        {
          title: 'Rails Code Safety Analyzer',
          readOnlyHint: true,
          destructiveHint: false,
          idempotentHint: true,
          openWorldHint: false
        }
      ) do |args|
        dry_run_analysis(args['code'])
      end
    end

    def execute_console_code(args)
      return 'Rails Active MCP is disabled' unless RailsActiveMcp.config.enabled

      executor = RailsActiveMcp::ConsoleExecutor.new(RailsActiveMcp.config)

      begin
        result = executor.execute(
          args['code'],
          timeout: args['timeout'] || 30,
          safe_mode: args['safe_mode'] != false,
          capture_output: args['capture_output'] != false
        )

        if result[:success]
          format_success_result(result)
        else
          "Error: #{result[:error]} (#{result[:error_class]})"
        end
      rescue RailsActiveMcp::SafetyError => e
        "Safety check failed: #{e.message}"
      rescue RailsActiveMcp::TimeoutError => e
        "Execution timed out: #{e.message}"
      rescue StandardError => e
        "Execution failed: #{e.message}"
      end
    end

    def get_model_info(model_name)
      return 'Rails Active MCP is disabled' unless RailsActiveMcp.config.enabled

      begin
        model_class = model_name.constantize
        return "#{model_name} is not an ActiveRecord model" unless model_class < ActiveRecord::Base

        info = []
        info << "Model: #{model_class.name}"
        info << "Table: #{model_class.table_name}"
        info << "Columns: #{model_class.column_names.join(', ')}"
        info << "Associations: #{model_class.reflect_on_all_associations.map(&:name).join(', ')}"
        info.join("\n")
      rescue NameError
        "Model '#{model_name}' not found"
      rescue StandardError => e
        "Error getting model info: #{e.message}"
      end
    end

    def execute_safe_query(args)
      return 'Rails Active MCP is disabled' unless RailsActiveMcp.config.enabled

      begin
        model_class = args['model'].constantize
        return "#{args['model']} is not an ActiveRecord model" unless model_class < ActiveRecord::Base

        # Only allow safe read-only methods
        safe_methods = %w[find find_by where select count sum average maximum minimum first last pluck ids exists?
                          empty? any? many? include?]
        query_method = args['query'].split('.').first

        return "Unsafe query method: #{query_method}" unless safe_methods.include?(query_method)

        result = model_class.instance_eval(args['query'])
        result.to_s
      rescue NameError
        "Model '#{args['model']}' not found"
      rescue StandardError => e
        "Error executing query: #{e.message}"
      end
    end

    def dry_run_analysis(code)
      return 'Rails Active MCP is disabled' unless RailsActiveMcp.config.enabled

      executor = RailsActiveMcp::ConsoleExecutor.new(RailsActiveMcp.config)

      begin
        analysis = executor.dry_run(code)

        output = []
        output << "Code: #{analysis[:code]}"
        output << "Safe: #{analysis[:safety_analysis][:safe] ? 'Yes' : 'No'}"
        output << "Read-only: #{analysis[:safety_analysis][:read_only] ? 'Yes' : 'No'}"
        output << "Risk level: #{analysis[:estimated_risk]}"
        output << "Would execute: #{analysis[:would_execute] ? 'Yes' : 'No'}"
        output << "Summary: #{analysis[:safety_analysis][:summary]}"

        if analysis[:safety_analysis][:violations].any?
          output << "\nViolations:"
          analysis[:safety_analysis][:violations].each do |violation|
            output << "  - #{violation[:description]} (#{violation[:severity]})"
          end
        end

        if analysis[:recommendations].any?
          output << "\nRecommendations:"
          analysis[:recommendations].each do |rec|
            output << "  - #{rec}"
          end
        end

        output.join("\n")
      rescue StandardError => e
        "Analysis failed: #{e.message}"
      end
    end

    def format_success_result(result)
      output = []
      output << "Code: #{result[:code]}"
      output << "Result: #{result[:return_value_string] || result[:return_value]}"
      output << "Output: #{result[:output]}" if result[:output].present?
      output << "Execution time: #{result[:execution_time]}s" if result[:execution_time]
      output << "Note: #{result[:note]}" if result[:note]
      output.join("\n")
    end

    def jsonrpc_error(id, code, message)
      {
        jsonrpc: JSONRPC_VERSION,
        id: id,
        error: { code: code, message: message }
      }
    end

    def error_response(status, message)
      [status, { 'Content-Type' => 'application/json' },
       [{ error: message }.to_json]]
    end
  end
end
