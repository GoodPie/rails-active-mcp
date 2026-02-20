# frozen_string_literal: true

require_relative 'config/environment'
require_relative 'lib/rails_active_mcp'

# Run the Rails Active MCP server
run RailsActiveMcp::McpServer.new
