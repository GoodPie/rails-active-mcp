# Rails Active MCP

A Ruby gem that provides secure Rails console access through Model Context Protocol (MCP) for AI agents and development tools like Claude Desktop, Warp Terminal, and other MCP clients. Built with a custom MCP server implementation for full control and flexibility.

## Features

- 🔒 **Safe Execution**: Advanced safety checks prevent dangerous operations
- 🚀 **Custom MCP Server**: Built-in MCP server with no external dependencies
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

Run the installer:

```bash
$ rails generate rails_active_mcp:install
```

This will:

- Create an initializer with configuration options
- Mount the custom MCP server at `/mcp`
- Create a `mcp.ru` server file for standalone usage
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

## Running the MCP Server

You have several options for running the MCP server:

### Option 1: Stdio server (recommended for Claude Desktop)

```bash
$ bundle exec rails-active-mcp-server stdio
```

This mode is required for Claude Desktop integration and other MCP clients that use stdio transport.

### Option 2: Rails-mounted (HTTP, good for development)

```bash
$ rails server
# MCP server available at http://localhost:3000/mcp
```

### Option 3: Standalone HTTP server

```bash
$ bundle exec rails-active-mcp-server http
# Default: http://localhost:3001

# Custom host/port
$ bundle exec rails-active-mcp-server http --host 0.0.0.0 --port 8080
```

### Option 4: Using rackup

```bash
$ rackup mcp.ru -p 3001
```

## Usage

### With MCP Clients

#### Claude Desktop Integration (Preferred)

Add to your Claude Desktop configuration file:

**Location:**
- macOS/Linux: `~/.config/claude-desktop/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "rails-active-mcp": {
      "command": "bundle",
      "args": ["exec", "rails-active-mcp-server", "stdio"],
      "cwd": "/path/to/your/rails/project"
    }
  }
}
```

Or if installed globally:

```json
{
  "mcpServers": {
    "rails-active-mcp": {
      "command": "rails-active-mcp-server",
      "args": ["stdio"],
      "cwd": "/path/to/your/rails/project"
    }
  }
}
```

Then in Claude Desktop, you can use prompts like:

- "Show me all users created in the last week"
- "What's the average order value?"
- "Check the User model schema and associations"
- "Analyze this code for safety: User.delete_all"

#### Warp Terminal Integration (HTTP)

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
        "-d", "@-",
        "http://localhost:3000/mcp"
      ]
    }
  }
}
```

#### Custom MCP Clients

The server implements the MCP protocol (JSONRPC 2.0). Connect any MCP-compatible client to:
- **Rails-mounted**: `http://localhost:3000/mcp`
- **Standalone**: `http://localhost:3001`

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

The Rails Active MCP server provides several built-in tools that will appear in Claude Desktop:

#### `rails_console_execute`

Execute Ruby code with safety checks and timeout protection:

```json
{
  "method": "tools/call",
  "params": {
    "name": "rails_console_execute",
    "arguments": {
      "code": "User.where(active: true).count",
      "timeout": 30,
      "safe_mode": true
    }
  }
}
```

#### `rails_model_info`

Get detailed information about Rails models:

```json
{
  "method": "tools/call",
  "params": {
    "name": "rails_model_info",
    "arguments": {
      "model_name": "User"
    }
  }
}
```

#### `rails_safe_query`

Execute safe, read-only database queries:

```json
{
  "method": "tools/call",
  "params": {
    "name": "rails_safe_query",
    "arguments": {
      "query": "where(active: true).count",
      "model": "User"
    }
  }
}
```

#### `rails_dry_run`

Analyze Ruby code for safety without executing:

```json
{
  "method": "tools/call",
  "params": {
    "name": "rails_dry_run",
    "arguments": {
      "code": "User.delete_all"
    }
  }
}
```

#### Adding Custom Tools

You can extend the server with additional tools by modifying the `McpServer` class in `lib/rails_active_mcp/mcp_server.rb` or `lib/rails_active_mcp/stdio_server.rb`:

```ruby
def register_default_tools
  # Built-in console execution tool
  register_tool('rails_console_execute', 'Execute Ruby code safely', {...})

  # Your custom tools
  register_tool('my_custom_tool', 'Description', {...}) do |args|
    # Tool implementation
  end
end
```

Common tool implementations can include:
- Code safety analysis
- Read-only database queries
- Model schema inspection
- Custom business logic tools

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

## Custom MCP Server Architecture

Rails Active MCP provides a custom-built MCP server implementation with no external dependencies. The server:

- Implements the Model Context Protocol (MCP)
- Uses JSON-RPC 2.0 over HTTP
- Supports essential MCP methods:
  - `initialize` - Server capabilities
  - `tools/list` - Available tools
  - `tools/call` - Execute tools
  - `resources/list` and `resources/read` - Resource access

### Server Implementation

The core server is implemented in `lib/rails_active_mcp/mcp_server.rb` and follows Rack middleware conventions, making it easy to mount in Rails or run standalone.

### Extending the Server

You can add custom tools and resources to the server by extending the registration methods:

```ruby
# In an initializer or plugin
RailsActiveMcp.server.instance_eval do
  register_tool('my_custom_tool', 'Description', {...}) do |args|
    # Tool implementation
  end
end
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

### Benefits of the Custom MCP Server

- **No External Dependencies**: Reduced attack surface with minimal dependencies
- **Full Control**: Complete visibility into the server implementation
- **Customizable Security**: Easily add additional security layers or checks
- **Simplified Deployment**: No need to manage external MCP server dependencies
- **Protocol Isolation**: MCP protocol implementation is self-contained and auditable

For security issues, please report using Github Issues.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and changes.