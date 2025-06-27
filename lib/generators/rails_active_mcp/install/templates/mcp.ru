# frozen_string_literal: true

require_relative 'config/environment'
require 'rails_active_mcp/sdk/server'

# Run the Rails Active MCP server using the official MCP Ruby SDK
# Note: This file is primarily for reference. The recommended way to run
# the server is using: bin/rails-active-mcp-server

server = RailsActiveMcp::SDK::Server.new
server.run
