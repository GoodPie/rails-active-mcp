# frozen_string_literal: true

module RailsActiveMcp
  class McpController < ApplicationController
    protect_from_forgery with: :null_session
    before_action :check_enabled
    before_action :set_cors_headers

    def handle
      return head :method_not_allowed unless request.post?
      return head :bad_request unless json_request?

      begin
        body = request.body.read
        data = JSON.parse(body)

        mcp_server = RailsActiveMcp::McpServer.new
        response_data = mcp_server.handle_jsonrpc_request(data)

        render json: response_data
      rescue JSON::ParserError
        render json: { error: 'Invalid JSON' }, status: :bad_request
      rescue StandardError => e
        RailsActiveMcp.logger.error "MCP Controller Error: #{e.message}"
        render json: { error: 'Internal Server Error' }, status: :internal_server_error
      end
    end

    def sse
      response.headers['Content-Type'] = 'text/event-stream'
      response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
      response.headers['Connection'] = 'keep-alive'
      response.headers['X-Accel-Buffering'] = 'no'

      # Send initial connection established event
      render plain: ": SSE connection established\n\nevent: endpoint\ndata: #{request.base_url}#{rails_active_mcp.root_path}messages\n\nretry: 100\n\n"
    end

    def health
      status = RailsActiveMcp.config.enabled ? 'healthy' : 'disabled'
      render json: {
        status: status,
        version: RailsActiveMcp::VERSION,
        timestamp: Time.current.iso8601
      }
    end

    def info
      render json: {
        name: 'Rails Active MCP',
        version: RailsActiveMcp::VERSION,
        description: 'Rails Console access via Model Context Protocol (MCP)',
        endpoints: {
          mcp: rails_active_mcp.root_path,
          health: rails_active_mcp.root_path + 'health'
        },
        enabled: RailsActiveMcp.config.enabled
      }
    end

    private

    def check_enabled
      return if RailsActiveMcp.config.enabled

      render json: { error: 'Rails Active MCP is disabled' }, status: :service_unavailable
    end

    def json_request?
      request.content_type&.include?('application/json')
    end

    def set_cors_headers
      response.headers['Access-Control-Allow-Origin'] = '*'
      response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
      response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
      response.headers['Access-Control-Max-Age'] = '86400'
    end
  end
end
