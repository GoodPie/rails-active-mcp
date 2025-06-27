# Rails Active MCP Documentation

## Introduction
Rails Active MCP is a Ruby gem that integrates the Model Context Protocol (MCP) into Rails applications using the official MCP Ruby SDK. It provides a secure, configurable, and professional server for AI agents and developer tools to interact with your Rails app via the standardized MCP protocol.

## How It Works
- **Official MCP SDK**: Built on the official MCP Ruby SDK (`mcp` gem) for robust protocol handling
- **Professional Implementation**: Automatic instrumentation, timing, and error reporting
- **Tooling**: Exposes four powerful tools (console execution, model info, safe queries, code analysis) to MCP clients
- **Safety**: Advanced safety checks, read-only modes, and audit logging protect your application from dangerous operations
- **Integration**: Easily added to any Rails application via a generator, with simplified configuration

## MCP Protocol Overview
- **MCP**: The Model Context Protocol is a standard for structured, secure, and auditable access to application internals for AI agents and developer tools
- **Official SDK**: Uses the official MCP Ruby SDK for protocol compliance and future-proof compatibility
- **STDIO Transport**: Perfect for Claude Desktop integration
- **JSON-RPC 2.0**: All communication uses JSON-RPC 2.0 with automatic protocol handling

## Installation & Setup
1. Add to your Gemfile:
   ```ruby
   gem 'rails-active-mcp'
   ```
2. Run:
   ```bash
   bundle install
   rails generate rails_active_mcp:install
   ```
   This creates an initializer and sets up the Rails integration.
3. Start the server:
   ```bash
   bundle exec rails-active-mcp-server
   ```

## Configuration
Edit `config/initializers/rails_active_mcp.rb`:

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

## Available Tools

### 1. console_execute
**Purpose:**
Execute Ruby code in the Rails console context with safety checks and timeout protection.

**Features:**
- Built-in dangerous operation detection
- Configurable execution timeout
- All executions logged for audit
- Safe execution environment

**Example Usage in Claude:**
> "Execute `User.where(active: true).count`"

---

### 2. model_info
**Purpose:**
Get detailed information about Rails models including schema, associations, and validations.

**Features:**
- Schema information (column types, constraints, indexes)
- Association details (has_many, belongs_to, has_one relationships)
- Validation rules and constraints
- Available instance and class methods

**Example Usage in Claude:**
> "Show me the User model structure"

---

### 3. safe_query
**Purpose:**
Execute safe, read-only database queries with automatic safety analysis.

**Features:**
- Read-only operations only (SELECT queries)
- Automatic query analysis for safety
- Result limiting to prevent large data dumps
- Works within your model definitions

**Example Usage in Claude:**
> "Get the 10 most recent orders"

---

### 4. dry_run
**Purpose:**
Analyze Ruby code for safety without executing it.

**Features:**
- Risk assessment and categorization
- Safety analysis with detailed feedback
- Recommendations for safer alternatives
- Zero execution guarantee

**Example Usage in Claude:**
> "Analyze this code for safety: `User.delete_all`"

## Security & Safety
- **Safety Checker**: Blocks dangerous operations (mass deletions, system commands, file access)
- **Read-Only Detection**: Identifies and promotes safe read-only operations
- **Audit Logging**: All executions are logged with detailed context
- **Configurable**: Fine-tune safety levels per environment

## Architecture

### Built on Official MCP Ruby SDK
Rails Active MCP leverages the official MCP Ruby SDK for:

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

## Testing & Development

### Running Tests
```bash
$ bundle exec rspec
```

### Testing MCP Integration
```bash
$ ./bin/test-mcp-output
```

### Debugging
Set the debug environment variable for detailed logging:
```bash
$ RAILS_MCP_DEBUG=1 bundle exec rails-active-mcp-server
```

## Extending the Gem
The gem is designed to be extensible. You can add custom tools by:

1. Creating new tool classes in your application
2. Following the MCP tool interface pattern
3. Registering tools with the server during initialization

Each tool must implement the standard MCP tool interface with proper input schemas and error handling.


For more details, see the main project README or explore the source code in `lib/rails_active_mcp/sdk/`. 