# frozen_string_literal: true

require 'json'
require 'rack'

module RailsActiveMcp
  class McpServer
    JSONRPC_VERSION = '2.0'
    MCP_VERSION = '2025-06-18'

    def initialize(app = nil)
      @app = app
      @resources = {}
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
      when 'ping'
        handle_ping(data)
      else
        jsonrpc_error(data['id'], -32_601, 'Method not found')
      end
    end

    def handle_ping(data)
      {
        jsonrpc: JSONRPC_VERSION,
        id: data['id'],
        result: {}
      }
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
      {
        jsonrpc: JSONRPC_VERSION,
        id: data['id'],
        result: { tools: tool_registry.tools_list }
      }
    end

    def handle_tools_call(data)
      tool_name = data.dig('params', 'name')
      arguments = data.dig('params', 'arguments') || {}

      begin
        result = tool_registry.call_tool(tool_name, arguments)
        {
          jsonrpc: JSONRPC_VERSION,
          id: data['id'],
          result: { content: [{ type: 'text', text: result.to_s }] }
        }
      rescue StandardError => e
        if e.message.include?('not found')
          jsonrpc_error(data['id'], -32_602, "Tool '#{tool_name}' not found")
        else
          jsonrpc_error(data['id'], -32_603, "Tool execution failed: #{e.message}")
        end
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

    private

    def tool_registry
      @tool_registry ||= ToolRegistry.instance
    end

    def json_request?(request)
      request.content_type&.include?('application/json')
    end

    def jsonrpc_error(id, code, message)
      {
        jsonrpc: JSONRPC_VERSION,
        id: id,
        error: {
          code: code,
          message: message
        }
      }
    end

    def error_response(status, message)
      [status, { 'Content-Type' => 'application/json' },
       [jsonrpc_error(nil, status, message).to_json]]
    end
  end
end
