# Rails Active MCP Documentation

## Introduction
Rails Active MCP is a Ruby gem that integrates the Model Context Protocol (MCP) into Rails applications. It provides a secure, configurable, and extensible server for AI agents and developer tools to interact with your Rails app via a standardized protocol.

## How It Works
- **Custom MCP Server**: Implements the MCP protocol (JSON-RPC 2.0 over HTTP) as a Rack middleware, mountable in Rails or runnable standalone.
- **Tooling**: Exposes a set of tools (e.g., safe console execution, model info, safe queries, code analysis) to MCP clients.
- **Safety**: Advanced safety checks, read-only modes, and audit logging protect your application from dangerous operations.
- **Integration**: Easily added to any Rails 7+ app via a generator, with configuration via an initializer.

## MCP Protocol Overview
- **MCP**: The Model Context Protocol is a standard for structured, secure, and auditable access to application internals for AI agents and developer tools.
- **Supported Methods**:
  - `initialize`: Returns server capabilities and protocol version.
  - `tools/list`: Lists available tools and their schemas.
  - `tools/call`: Executes a tool with given arguments.
  - `resources/list` and `resources/read`: (Stubbed, for future resource access.)
- **JSON-RPC 2.0**: All communication uses JSON-RPC 2.0 over HTTP POST.

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
   This creates an initializer, mounts the MCP server at `/mcp`, and sets up audit logging.
3. Start the server:
   - Rails: `rails server` (MCP at `/mcp`)
   - Standalone: `bundle exec rails-active-mcp-server`
   - Rack: `rackup mcp.ru -p 3001`

## Configuration
Edit `config/initializers/rails_active_mcp.rb`:
- Enable/disable the server
- Safety mode (production = strict)
- Allowed/blocked models
- Enable/disable mutation tools
- Audit log location
- Environment presets: `production_mode!`, `strict_mode!`, `permissive_mode!`

## Available Tools
- **rails_console_execute**: Execute Ruby code in Rails with safety checks
- **rails_model_info**: Inspect model schema and associations
- **rails_safe_query**: Run safe, read-only queries on models
- **rails_dry_run**: Analyze code for safety without executing

Each tool is described in the MCP `tools/list` response and can be extended or customized.

## Security & Safety
- **Safety Checker**: Blocks dangerous operations (e.g., mass deletions, system commands, file access)
- **Read-Only Mode**: Enforced in production
- **Audit Logging**: All executions are logged to `log/rails_active_mcp.log`
- **Configurable**: Fine-tune what is allowed per environment

## Extending the Gem
- Add custom tools by calling `RailsActiveMcp.server.register_tool` in an initializer or plugin.
- Tools must define a name, description, input schema, and a handler block.

## Testing & Specification Adherence
- All features are covered by RSpec tests in the `spec/` directory.
- Follows standard Ruby/Rails conventions for gems, engines, and generators.
- MCP protocol compliance is maintained as per [modelcontextprotocol.io](https://modelcontextprotocol.io/introduction).

## Per-Tool Breakdown

### 1. rails_console_execute
**Purpose:**
Execute arbitrary Ruby code in the Rails console context, with safety checks and output capture.

**Input Parameters:**
- `code` (string, required): Ruby code to execute.
- `safe_mode` (boolean, optional): Enable safety checks (default: true).
- `timeout` (integer, optional): Timeout in seconds (default: 30).
- `capture_output` (boolean, optional): Capture console output (default: true).

**Output:**
- On success: Code, result, output (if any), execution time, and notes.
- On error: Error message and class.

**Example Usage:**
```json
{
  "method": "tools/call",
  "params": {
    "name": "rails_console_execute",
    "arguments": {
      "code": "User.count"
    }
  }
}
```

---

### 2. rails_model_info
**Purpose:**
Get detailed information about a Rails model, including schema, associations, and validations.

**Input Parameters:**
- `model` (string, required): Model class name (e.g., "User").
- `include_schema` (boolean, optional): Include database schema info (default: true).
- `include_associations` (boolean, optional): Include model associations (default: true).
- `include_validations` (boolean, optional): Include model validations (default: true).

**Output:**
- Model name, table, primary key, schema (columns, types, null/default), associations, validations.
- On error: Error message (e.g., model not found).

**Example Usage:**
```json
{
  "method": "tools/call",
  "params": {
    "name": "rails_model_info",
    "arguments": {
      "model": "User"
    }
  }
}
```

---

### 3. rails_safe_query
**Purpose:**
Execute safe, read-only database queries on Rails models.

**Input Parameters:**
- `model` (string, required): Model class name (e.g., "User").
- `method` (string, required): Query method (e.g., "where", "count").
- `args` (array, optional): Arguments for the query method.
- `limit` (integer, optional): Limit results (default: 100).

**Output:**
- Query string, count, and result (as inspected Ruby object).
- On error: Error message.

**Example Usage:**
```json
{
  "method": "tools/call",
  "params": {
    "name": "rails_safe_query",
    "arguments": {
      "model": "User",
      "method": "where",
      "args": [{"active": true}],
      "limit": 10
    }
  }
}
```

---

### 4. rails_dry_run
**Purpose:**
Analyze Ruby code for safety and risk without executing it.

**Input Parameters:**
- `code` (string, required): Ruby code to analyze.

**Output:**
- Code, safety status, read-only status, risk level, summary, violations, and recommendations.

**Example Usage:**
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

---
For more details, see the main project README or source code. 