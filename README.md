# Rails Console MCP

A Ruby gem that provides secure Rails console access through Model Context Protocol (MCP) for AI agents and development
tools like Warp Terminal.

## Features

- 🔒 **Safe Execution**: Advanced safety checks prevent dangerous operations
- 🚀 **MCP Integration**: Works seamlessly with Active MCP and MCP clients
- 📊 **Read-Only Queries**: Safe database querying with automatic result limiting
- 🔍 **Code Analysis**: Dry-run capabilities to analyze code before execution
- 📝 **Audit Logging**: Complete execution logging for security and debugging
- ⚙️ **Configurable**: Flexible configuration for different environments
- 🛡️ **Production Ready**: Strict safety modes for production environments

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rails-active-mcp'
```

And then execute:

```bash
$ bundle install
```

Install ActionMCP if not already installed:

```bash
$ bundle add actionmcp
```

Run the installer:

```bash
$ rails generate rails_active_mcp:install
```

This will:

- Create an initializer with configuration options
- Mount the ActionMCP engine at `/mcp`
- Create MCP tools in `app/mcp/tools/`
- Create a `mcp.ru` server file
- Set up audit logging

## Configuration

The gem is configured in `config/initializers/rails_active_mcp.rb`:

```ruby
RailsActiveMcp.configure do |config|
  # Basic settings
  config.enabled = true
  config.safe_mode = Rails.env.production?
  config.default_timeout = 30
  config.max_results = 100

  # Model access control
  config.allowed_models = %w[User Post Comment] # Empty = all allowed
  config.blocked_models = %w[AdminUser Secret]

  # Security settings
  config.enable_mutation_tools = !Rails.env.production?
  config.log_executions = true
  config.audit_file = Rails.root.join("log", "rails_active_mcp.log")

  # Environment presets
  config.production_mode! # Very strict
  config.strict_mode! # Safe defaults
  config.permissive_mode! # Development friendly
end
```

## Usage

### With Warp Terminal

Add to your Warp MCP configuration:

```json
{
  "mcpServers": {
    "rails-console": {
      "command": "curl",
      "args": [
        "-X",
        "POST",
        "-H",
        "Content-Type: application/json",
        "http://localhost:3000/mcp"
      ]
    }
  }
}
```

Then in Warp, you can use prompts like:

- "Show me all users created in the last week"
- "What's the average order value?"
- "Check the User model schema and associations"

### Direct Usage

```ruby
# Execute code safely
result = RailsActiveMcp.execute("User.count")
puts result[:return_value] # => 42

# Check if code is safe
RailsActiveMcp.safe?("User.delete_all") # => false

# Analyze code without executing
executor = RailsActiveMcp::ConsoleExecutor.new(RailsActiveMcp.config)
analysis = executor.dry_run("User.delete_all")
puts analysis[:estimated_risk] # => :critical
```

### Available MCP Tools

#### `console_execute`

Execute Ruby code with safety checks:

```json
{
  "tool": "console_execute",
  "arguments": {
    "code": "User.where(active: true).count",
    "safe_mode": true,
    "timeout": 30
  }
}
```

#### `safe_query`

Execute read-only database queries:

```json
{
  "tool": "safe_query",
  "arguments": {
    "model": "User",
    "method": "where",
    "args": [
      {
        "active": true
      }
    ],
    "limit": 50
  }
}
```

#### `dry_run`

Analyze code safety without execution:

```json
{
  "tool": "dry_run",
  "arguments": {
    "code": "User.delete_all"
  }
}
```

#### `model_info`

Get model schema and associations:

```json
{
  "tool": "model_info",
  "arguments": {
    "model": "User",
    "include_schema": true,
    "include_associations": true,
    "include_validations": true
  }
}
```

## Safety Features

### Automatic Detection of Dangerous Operations

The gem automatically detects and blocks:

- Mass deletions (`delete_all`, `destroy_all`)
- System commands (`system`, `exec`, backticks)
- File operations (`File.delete`, `FileUtils`)
- Raw SQL execution
- Code evaluation (`eval`, `send`)
- Process manipulation (`exit`, `fork`)

### Safety Levels

- **Critical**: Never allowed (system commands, file deletion)
- **High**: Blocked in safe mode (mass deletions, eval)
- **Medium**: Logged but allowed (raw SQL, update_all)
- **Low**: Generally safe (environment access, require)

### Read-Only Mode

The gem can detect read-only operations and provide additional safety:

```ruby
# These are considered safe read-only operations
User.find(1)
User.where(active: true).count
Post.includes(:comments).limit(10)
```

## Rake Tasks

```bash
# Check code safety
rails rails_active_mcp:check_safety['User.count']

# Execute code
rails rails_active_mcp:execute['User.count']

# Test MCP tools
rails rails_active_mcp:test_tools

# View configuration
rails rails_active_mcp:config

# View audit log
rails rails_active_mcp:audit_log[20]

# Clear audit log
rails rails_active_mcp:clear_audit_log
```

## Audit Logging

All executions are logged to `log/rails_active_mcp.log`:

```json
{
  "timestamp": "2025-01-15T10:30:00Z",
  "code": "User.count",
  "user": {
    "environment": "development"
  },
  "safety_check": {
    "safe": true,
    "read_only": true,
    "violations": []
  }
}
```

## Environment-Specific Configuration

### Production

```ruby
config.production_mode!
# - Very strict safety checks
# - Read-only replica execution
# - Comprehensive logging
# - No mutation tools
```

### Development

```ruby
config.permissive_mode!
# - Relaxed safety (but still protected)
# - Mutation tools enabled
# - Higher timeouts and limits
```

### Testing

```ruby
config.strict_mode!
# - Safe defaults
# - No mutations
# - Fast timeouts
```

## Integration with ActionMCP

```ruby
# In config/initializers/rails_active_mcp.rb
if defined?(ActionMCP)
  # Tools will be auto-discovered from app/mcp/tools/
  # Make sure to mount the ActionMCP engine in routes.rb:
  # mount ActionMCP::Engine, at: "/mcp"
end

# You'll need to create a mcp.ru file:
# require_relative "config/environment"
# run ActionMCP::Engine
```

## Error Handling

The gem provides specific error types:

- `RailsActiveMcp::SafetyError`: Code failed safety checks
- `RailsActiveMcp::TimeoutError`: Execution timed out
- `RailsActiveMcp::ExecutionError`: General execution failure

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Security

This gem provides multiple layers of security, but always:

- Review the configuration for your environment
- Monitor the audit logs
- Use read-only database replicas in production when possible
- Restrict model access as needed
- Test safety patterns thoroughly

For security issues, please email [security@yourcompany.com].

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and changes.