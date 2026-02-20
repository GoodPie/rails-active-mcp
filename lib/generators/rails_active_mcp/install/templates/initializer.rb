# frozen_string_literal: true

require 'rails_active_mcp'

RailsActiveMcp.configure do |config|
  # Execution timeout in seconds
  config.command_timeout = 30

  # Logging configuration
  config.enable_logging = true
  config.log_level = :info # :debug, :info, :warn, :error

  # Safety configuration
  config.safe_mode = true        # Enable safety checks by default
  config.max_results = 100       # Limit query results to prevent large dumps
  config.log_executions = true   # Log all executions for audit trail

  # Model access control (empty arrays allow all)
  config.allowed_models = [] # Whitelist specific models if needed
  # config.allowed_models = %w[User Post Comment] # Example: restrict to specific models

  # Custom safety patterns for your application
  # config.custom_safety_patterns = [
  #   { pattern: /YourDangerousMethod/, description: "Your custom dangerous operation" }
  # ]

  # Environment-specific adjustments
  case Rails.env
  when 'production'
    # Strict settings for production
    config.safe_mode = true
    config.log_level = :warn
    config.command_timeout = 15
    config.max_results = 50
    config.log_executions = true
    config.allowed_models = [] # Consider restricting models in production

  when 'development'
    # More permissive settings for development
    config.safe_mode = false # Allow more operations during development
    config.log_level = :debug
    config.command_timeout = 60
    config.max_results = 200
    config.log_executions = false

  when 'test'
    # Test-friendly settings
    config.safe_mode = true
    config.log_level = :error
    config.command_timeout = 30
    config.log_executions = false
  end
end

# Rails Active MCP is now ready!
#
# Available MCP Tools:
# - console_execute: Execute Ruby code with safety checks
# - model_info: Get detailed information about Rails models
# - safe_query: Execute safe read-only database queries
# - dry_run: Analyze Ruby code for safety without execution
#
# Quick Start:
# 1. Start the server: bin/rails-active-mcp-server
# 2. Configure Claude Desktop (see post-install instructions)
# 3. Try asking Claude: "Show me all users created in the last week"
#
# Testing the installation:
# - Run: bin/rails-active-mcp-wrapper (should output JSON responses)
# - Test with: RAILS_MCP_DEBUG=1 bin/rails-active-mcp-server
# - Check rake tasks: rails -T rails_active_mcp
#
# Documentation: https://github.com/goodpie/rails-active-mcp
# Need help? Create an issue or check the troubleshooting guide.
