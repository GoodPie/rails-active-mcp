Note: This is just a personal project and while it works for the most part, I am still developing it and actively trying to make it a bit more useful for my uses.

# Rails Active MCP

A Ruby gem that provides secure Rails console access through Model Context Protocol (MCP) for AI agents and development tools like Claude Desktop. Built using the official MCP Ruby SDK for professional protocol handling and future-proof compatibility.



## Features

- 🔒 **Safe Execution**: Advanced safety checks prevent dangerous operations
- 🚀 **Official MCP SDK**: Built with the official MCP Ruby SDK for robust protocol handling
- 📊 **Read-Only Queries**: Safe database querying with automatic result limiting
- 🔍 **Code Analysis**: Dry-run capabilities to analyze code before execution
- 📝 **Audit Logging**: Complete execution logging for security and debugging
- ⚙️ **Configurable**: Flexible configuration for different environments
- 🛡️ **Production Ready**: Strict safety modes for production environments
- ⚡ **Professional Implementation**: Built-in instrumentation, timing, and error handling

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rails-active-mcp'
```

And then execute:

```bash
bundle install
```

Run the installer:

```bash
rails generate rails_active_mcp:install
```

This will:

- Create an initializer with configuration options
- Mount the MCP server for Rails integration
- Create a `mcp.ru` server file for standalone usage
- Set up audit logging

## Configuration

The gem is configured in `config/initializers/rails_active_mcp.rb`:

```ruby
RailsActiveMcp.configure do |config|
  # Core configuration options
  config.allowed_commands = %w[
    ls pwd cat head tail grep find wc
    rails console rails runner
    bundle exec rspec bundle exec test
    git status git log git diff
  ]
  config.command_timeout = 30
  config.enable_logging = true
  config.log_level = :info
end
```

## Running the MCP Server

The server runs in STDIO mode, perfect for Claude Desktop integration:

```bash
$ bundle exec rails-active-mcp-server
```

The server automatically:
- Loads your Rails application
- Initializes all models and configurations
- Provides secure access to your Rails environment
- Uses the official MCP Ruby SDK for protocol handling

## Usage

### Claude Desktop Integration (Recommended)

Add to your Claude Desktop configuration file:

**Location:**
- macOS/Linux: `~/.config/claude-desktop/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "rails-active-mcp": {
      "command": "bundle",
      "args": ["exec", "rails-active-mcp-server"],
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

### Direct Usage

```ruby
# Execute code safely
result = RailsActiveMcp.execute("User.count")

# Check if code is safe
RailsActiveMcp.safe?("User.delete_all") # => false
```

## Available MCP Tools

The Rails Active MCP server provides four powerful tools that appear automatically in Claude Desktop:

### 1. `console_execute`

Execute Ruby code with safety checks and timeout protection:

- **Purpose**: Run Rails console commands safely
- **Safety**: Built-in dangerous operation detection
- **Timeout**: Configurable execution timeout
- **Logging**: All executions are logged for audit

**Example Usage in Claude:**
> "Execute `User.where(active: true).count`"

### 2. `model_info`

Get detailed information about Rails models:

- **Schema Information**: Column types, constraints, indexes
- **Associations**: Has_many, belongs_to, has_one relationships
- **Validations**: All model validations and rules
- **Methods**: Available instance and class methods

**Example Usage in Claude:**
> "Show me the User model structure"

### 3. `safe_query`

Execute safe, read-only database queries:

- **Read-Only**: Only SELECT operations allowed
- **Safe Execution**: Automatic query analysis
- **Result Limiting**: Prevents large data dumps
- **Model Context**: Works within your model definitions

**Example Usage in Claude:**
> "Get the 10 most recent orders"

### 4. `dry_run`

Analyze Ruby code for safety without executing:

- **Risk Assessment**: Categorizes code by danger level
- **Safety Analysis**: Identifies potential issues
- **Recommendations**: Suggests safer alternatives
- **Zero Execution**: Never runs the actual code

**Example Usage in Claude:**
> "Analyze this code for safety: `User.delete_all`"

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

## Architecture

### Built on Official MCP Ruby SDK

Rails Active MCP uses the official MCP Ruby SDK (`mcp` gem) for:

- **Professional Protocol Handling**: Robust JSON-RPC 2.0 implementation
- **Built-in Instrumentation**: Automatic timing and error reporting
- **Future-Proof**: Automatic updates as MCP specification evolves
- **Standards Compliance**: Full MCP protocol compatibility

### Server Implementation

The server is implemented in `lib/rails_active_mcp/sdk/server.rb` and provides:

- **STDIO Transport**: Perfect for Claude Desktop integration
- **Tool Registration**: Automatic discovery of available tools
- **Error Handling**: Comprehensive error reporting and recovery
- **Rails Integration**: Deep integration with Rails applications

### Tool Architecture

Each tool is implemented as a separate class in `lib/rails_active_mcp/sdk/tools/`:

- `ConsoleExecuteTool`: Safe code execution
- `ModelInfoTool`: Model introspection
- `SafeQueryTool`: Read-only database access
- `DryRunTool`: Code safety analysis

## Error Handling

The gem provides specific error types:

- `RailsActiveMcp::SafetyError`: Code failed safety checks
- `RailsActiveMcp::TimeoutError`: Execution timed out
- `RailsActiveMcp::ExecutionError`: General execution failure

All errors are properly reported through the MCP protocol with detailed messages.

## Development and Testing

### Running Tests

```bash
$ bundle exec rspec
```

### Testing MCP Integration

```bash
$ ./bin/test-mcp-output
```

This tests the MCP server output redirection and JSON protocol compliance.

### Debugging

Set the debug environment variable for detailed logging:

```bash
$ RAILS_MCP_DEBUG=1 bundle exec rails-active-mcp-server
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

The gem is available as open source under the [MIT License](https://opensource.org/licenses/MIT).

## Changelog

### Version 2.0.0 (Latest)

- **BREAKING**: Migrated to official MCP Ruby SDK
- **BREAKING**: Removed custom MCP server implementation
- **BREAKING**: Simplified configuration options
- **NEW**: Professional protocol handling with built-in instrumentation
- **NEW**: Automatic MCP specification compliance
- **IMPROVED**: 85% reduction in codebase complexity
- **IMPROVED**: Better error handling and reporting
- **IMPROVED**: Future-proof architecture

### Previous Versions

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.
