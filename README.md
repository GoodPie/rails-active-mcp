[![Gem Version](https://badge.fury.io/rb/rails-active-mcp.svg?icon=si%3Arubygems)](https://badge.fury.io/rb/rails-active-mcp)

Note: This is just a personal project and while it works for the most part, I am still developing it and actively trying to make it a bit more useful for my uses.

# Rails Active MCP

A Ruby gem that provides secure Rails console access through [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) for AI agents and development tools. Built using the official MCP Ruby SDK for professional protocol handling and future-proof compatibility.

Works with any MCP-compatible client, including Claude Desktop, Claude Code, VS Code (GitHub Copilot), Cursor, Windsurf, ChatGPT, Gemini CLI, Amazon Q Developer, JetBrains IDEs, Zed, Warp, Cline, and [many more](https://modelcontextprotocol.io/clients).



## Quick Start

Get up and running in three steps:

### 1. Install the gem

Add to your Rails application's `Gemfile`:

```ruby
gem 'rails-active-mcp'
```

```bash
bundle install
```

### 2. Run the installer

```bash
rails generate rails_active_mcp:install
```

This creates an initializer, server scripts, and prompts you to select which MCP clients you use. It will automatically generate the correct project-level config files (`.mcp.json`, `.cursor/mcp.json`, `.vscode/mcp.json`, etc.) so your MCP client detects the server when you open the project.

### 3. Connect your MCP client

If you selected your MCP client during installation, you're done — just open the project and the server will be detected automatically.

For manual configuration or additional clients, the server uses STDIO transport. Below are configuration examples for popular tools.

<details>
<summary><strong>Claude Desktop</strong></summary>

Edit your config file:
- **macOS/Linux:** `~/.config/claude-desktop/claude_desktop_config.json`
- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

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

Restart Claude Desktop and the tools will appear automatically.
</details>

<details>
<summary><strong>Claude Code</strong></summary>

From your Rails project directory:

```bash
claude mcp add rails-active-mcp -- bundle exec rails-active-mcp-server
```

Or add it to your project's `.mcp.json`:

```json
{
  "mcpServers": {
    "rails-active-mcp": {
      "command": "bundle",
      "args": ["exec", "rails-active-mcp-server"]
    }
  }
}
```
</details>

<details>
<summary><strong>VS Code (GitHub Copilot)</strong></summary>

Add to your workspace `.vscode/mcp.json`:

```json
{
  "servers": {
    "rails-active-mcp": {
      "command": "bundle",
      "args": ["exec", "rails-active-mcp-server"],
      "cwd": "${workspaceFolder}"
    }
  }
}
```

Tools are available in Copilot's Agent mode.
</details>

<details>
<summary><strong>Cursor</strong></summary>

Add to your project's `.cursor/mcp.json`:

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
</details>

<details>
<summary><strong>Windsurf</strong></summary>

Add to your project's `.windsurf/mcp.json`:

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
</details>

<details>
<summary><strong>Zed</strong></summary>

Add to your Zed settings (`settings.json`):

```json
{
  "context_servers": {
    "rails-active-mcp": {
      "command": {
        "path": "bundle",
        "args": ["exec", "rails-active-mcp-server"],
        "env": {}
      }
    }
  }
}
```
</details>

<details>
<summary><strong>ChatGPT Desktop</strong></summary>

In ChatGPT Desktop, go to **Settings > Connectors > Advanced > Developer Mode**, then add:

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
</details>

<details>
<summary><strong>Other MCP Clients</strong></summary>

Any MCP client that supports STDIO transport can connect to this server. The key details:

- **Command:** `bundle exec rails-active-mcp-server`
- **Working directory:** Your Rails project root
- **Transport:** STDIO (stdin/stdout)

See the [full list of MCP clients](https://modelcontextprotocol.io/clients) for more options.
</details>

Once connected, four tools will appear automatically: `console_execute`, `model_info`, `safe_query`, and `dry_run`.

Try asking your AI assistant:

- "Show me all users created in the last week"
- "What's the average order value?"
- "Check the User model schema and associations"
- "Analyze this code for safety: User.delete_all"

## Features

- 🔒 **Safe Execution**: Advanced safety checks prevent dangerous operations
- 🚀 **Official MCP SDK**: Built with the official MCP Ruby SDK for robust protocol handling
- 📊 **Read-Only Queries**: Safe database querying with automatic result limiting
- 🔍 **Code Analysis**: Dry-run capabilities to analyze code before execution
- 📝 **Audit Logging**: Complete execution logging for security and debugging
- ⚙️ **Configurable**: Flexible configuration for different environments
- 🛡️ **Production Ready**: Strict safety modes for production environments
- ⚡ **Professional Implementation**: Built-in instrumentation, timing, and error handling

## Configuration

The installer creates a default configuration at `config/initializers/rails_active_mcp.rb`. The defaults work out of the box, but you can customize behavior:

```ruby
RailsActiveMcp.configure do |config|
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

## Usage

### MCP Client (Recommended)

Once connected (see [Quick Start](#quick-start)), your MCP client automatically runs the server for you. The server loads your Rails application, initializes models, and provides secure access to your Rails environment via STDIO transport.

### Direct Usage

You can also use the gem directly in Ruby:

```ruby
# Execute code safely
result = RailsActiveMcp.execute("User.count")

# Check if code is safe
RailsActiveMcp.safe?("User.delete_all") # => false
```

### Running the Server Manually

If you need to run the server directly (e.g., for debugging):

```bash
bundle exec rails-active-mcp-server

# With debug logging
RAILS_MCP_DEBUG=1 bundle exec rails-active-mcp-server
```

## Available MCP Tools

The Rails Active MCP server provides four powerful tools that appear automatically in any connected MCP client:

### 1. `console_execute`

Execute Ruby code with safety checks and timeout protection:

- **Purpose**: Run Rails console commands safely
- **Safety**: Built-in dangerous operation detection
- **Timeout**: Configurable execution timeout
- **Logging**: All executions are logged for audit

**Example prompt:**
> "Execute `User.where(active: true).count`"

### 2. `model_info`

Get detailed information about Rails models:

- **Schema Information**: Column types, constraints, indexes
- **Associations**: Has_many, belongs_to, has_one relationships
- **Validations**: All model validations and rules
- **Methods**: Available instance and class methods

**Example prompt:**
> "Show me the User model structure"

### 3. `safe_query`

Execute safe, read-only database queries:

- **Read-Only**: Only SELECT operations allowed
- **Safe Execution**: Automatic query analysis
- **Result Limiting**: Prevents large data dumps
- **Model Context**: Works within your model definitions

**Example prompt:**
> "Get the 10 most recent orders"

### 4. `dry_run`

Analyze Ruby code for safety without executing:

- **Risk Assessment**: Categorizes code by danger level
- **Safety Analysis**: Identifies potential issues
- **Recommendations**: Suggests safer alternatives
- **Zero Execution**: Never runs the actual code

**Example prompt:**
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

- **STDIO Transport**: Compatible with all major MCP clients
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

```bash
# Run tests
bundle exec rspec

# Test MCP server protocol compliance
./bin/test-mcp-output
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
