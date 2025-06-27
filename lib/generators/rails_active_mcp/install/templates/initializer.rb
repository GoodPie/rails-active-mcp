require 'rails_active_mcp'

RailsActiveMcp.configure do |config|
  # Core configuration options
  config.allowed_commands = %w[
    ls pwd cat head tail grep find wc
    rails console rails runner
    bundle exec rspec bundle exec test
    git status git log git diff
  ]

  # Execution timeout in seconds
  config.command_timeout = 30

  # Logging configuration
  config.enable_logging = true
  config.log_level = :info # :debug, :info, :warn, :error

  # Environment-specific adjustments
  if Rails.env.production?
    # More restrictive settings for production
    config.log_level = :warn
    config.command_timeout = 15
  elsif Rails.env.development?
    # More permissive settings for development
    config.log_level = :debug
    config.command_timeout = 60
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
# To start the server:
#   bin/rails-active-mcp-server
#
# For Claude Desktop integration, see the post-install instructions.
