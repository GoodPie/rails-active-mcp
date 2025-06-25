require_relative "config/environment"

# Load Rails Console MCP tools
Dir[Rails.root.join("app/mcp/tools/**/*.rb")].each { |f| require f }

# Run the ActionMCP engine
run ActionMCP::Engine