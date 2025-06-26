require 'rails_active_mcp'

RailsActiveMcp.configure do |config|
  # Enable/disable the MCP server
  config.enabled = true

  # Safety configuration
  config.safe_mode = Rails.env.production? # Always safe in production
  config.default_timeout = 30 # seconds
  config.max_results = 100

  # Model access control
  # config.allowed_models = %w[User Post Comment]  # Empty means all allowed
  # config.blocked_models = %w[AdminUser Secret]   # Models to never allow access

  # Mutation tools (dangerous operations)
  config.enable_mutation_tools = !Rails.env.production?

  # Logging and auditing
  config.log_executions = true
  config.audit_file = Rails.root.join('log', 'rails_active_mcp.log')

  # Server configuration
  config.server_mode = :stdio # :stdio for Claude Desktop, :http for web integrations
  config.server_host = 'localhost'
  config.server_port = 3001

  # Environment-specific settings
  case Rails.env
  when 'production'
    config.production_mode! # Very strict settings
  when 'development'
    config.permissive_mode! # More relaxed for development
  when 'test'
    config.strict_mode! # Safe for testing
  end

  # Add custom safety patterns
  # config.add_safety_pattern(/CustomDangerousMethod/, "Custom dangerous operation")

  # Operations that require manual confirmation
  config.require_confirmation_for = %i[delete destroy update_all delete_all]
end
