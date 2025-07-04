# Rails Active MCP

A globally installable Ruby gem that provides secure Rails console access through Model Context Protocol (MCP) for AI agents and development tools like Claude Desktop. Built using the official MCP Ruby SDK with automatic Rails project detection and Thor-based CLI.

[![Gem Version](https://badge.fury.io/rb/rails-active-mcp.svg)](https://badge.fury.io/rb/rails-active-mcp)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## ✨ Features

- 🌍 **Global Installation**: Install once, use with any Rails project
- 🔍 **Auto-Detection**: Automatically finds Rails projects from any directory
- 🔒 **Safe Execution**: Advanced safety checks prevent dangerous operations
- 🚀 **Official MCP SDK**: Built with the official MCP Ruby SDK for robust protocol handling
- 📊 **Read-Only Queries**: Safe database querying with automatic result limiting
- 🔍 **Code Analysis**: Dry-run capabilities to analyze code before execution
- 📝 **Audit Logging**: Complete execution logging for security and debugging
- ⚙️ **Flexible Configuration**: JSON config files, environment variables, and CLI options
- 🛡️ **Production Ready**: Strict safety modes for production environments
- ⚡ **Professional Implementation**: Built-in instrumentation, timing, and error handling
- 🎯 **Thor CLI**: Comprehensive command-line interface with help system

## 🚀 Quick Start

### Global Installation

```bash
gem install rails-active-mcp
```

### Start the Server

From any Rails project directory:

```bash
rails-active-mcp-server start --auto-detect
```

Or specify a project explicitly:

```bash
rails-active-mcp-server start --project /path/to/rails/app
```

### Configure Claude Desktop

Add to your Claude Desktop configuration:

```json
{
  "mcpServers": {
    "rails-active-mcp": {
      "command": "rails-active-mcp-server",
      "args": ["start", "--auto-detect", "--safe-mode"]
    }
  }
}
```

That's it! Claude Desktop will now have secure access to your Rails applications.

## 📦 Installation

### Global Installation (Recommended)

Install the gem globally to use with any Rails project:

```bash
gem install rails-active-mcp
```

### Project-Specific Installation

Add to your Rails application's Gemfile:

```ruby
gem 'rails-active-mcp'
```

Then execute:

```bash
bundle install
```

## 🎯 CLI Commands

Rails Active MCP provides a comprehensive Thor-based CLI with multiple commands:

### `start` - Start the MCP Server

Start the Rails Active MCP server for AI agent integration:

```bash
# Auto-detect Rails project from current directory
rails-active-mcp-server start --auto-detect

# Specify explicit project path
rails-active-mcp-server start --project /path/to/rails/app

# Show configuration without starting (dry-run)
rails-active-mcp-server start --dry-run

# Start with custom settings
rails-active-mcp-server start --auto-detect --safe-mode --timeout 60 --log-level debug
```

**Options:**
- `-p, --project PATH` - Explicit Rails project path
- `-a, --auto-detect` - Auto-detect Rails project from current directory
- `--safe-mode` - Enable safe mode (blocks dangerous operations)
- `--timeout SECONDS` - Command timeout in seconds (default: 30)
- `--log-level LEVEL` - Log level: debug, info, warn, error (default: info)
- `--dry-run` - Show configuration without starting server

### `generate_config` - Generate Configuration File

Create a JSON configuration file for project-specific settings:

```bash
# Generate config for current project
rails-active-mcp-server generate_config

# Generate config for specific project
rails-active-mcp-server generate_config --project /path/to/rails/app
```

This creates `config/rails_active_mcp.json` with default settings that you can customize.

### `validate_project` - Validate Rails Project

Check if a Rails project is compatible with Rails Active MCP:

```bash
# Validate current project
rails-active-mcp-server validate_project

# Validate specific project
rails-active-mcp-server validate_project --project /path/to/rails/app

# Output validation results as JSON
rails-active-mcp-server validate_project --json
```

### Help System

Get help for any command:

```bash
# General help
rails-active-mcp-server --help

# Command-specific help
rails-active-mcp-server help start
rails-active-mcp-server help generate_config
rails-active-mcp-server help validate_project
```

## ⚙️ Configuration

Rails Active MCP supports a flexible configuration hierarchy:

1. **Defaults** (lowest priority)
2. **Global config file** (`~/.config/rails_active_mcp/config.json`)
3. **Project config file** (`./config/rails_active_mcp.json`)
4. **Environment variables** (`RAILS_MCP_*`)
5. **CLI arguments** (highest priority)

### Configuration File Format

Create configuration files in JSON format:

```json
{
  "safe_mode": true,
  "command_timeout": 30,
  "log_level": "info",
  "enable_logging": true,
  "max_results": 100,
  "allowed_commands": [
    "ls", "pwd", "cat", "head", "tail", "grep", "find", "wc",
    "rails console", "rails runner",
    "bundle exec rspec", "bundle exec test",
    "git status", "git log", "git diff"
  ],
  "blocked_patterns": [
    "*.delete_all", "*.destroy_all", "system", "exec", "`"
  ],
  "allowed_models": []
}
```

### Environment Variables

Configure using environment variables with `RAILS_MCP_` prefix:

```bash
export RAILS_MCP_SAFE_MODE=true
export RAILS_MCP_TIMEOUT=45
export RAILS_MCP_LOG_LEVEL=debug
export RAILS_MCP_MAX_RESULTS=200
```

### Configuration Locations

- **Global config**: `~/.config/rails_active_mcp/config.json`
- **Project config**: `./config/rails_active_mcp.json`
- **XDG config**: `$XDG_CONFIG_HOME/rails_active_mcp/config.json`

## 🔌 MCP Client Configuration

### Claude Desktop

**Configuration File Location:**
- macOS/Linux: `~/.config/claude-desktop/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`

**Basic Configuration:**
```json
{
  "mcpServers": {
    "rails-active-mcp": {
      "command": "rails-active-mcp-server",
      "args": ["start", "--auto-detect"]
    }
  }
}
```

**Advanced Configuration:**
```json
{
  "mcpServers": {
    "rails-active-mcp": {
      "command": "rails-active-mcp-server",
      "args": ["start", "--auto-detect", "--safe-mode", "--timeout", "60"],
      "env": {
        "RAILS_MCP_LOG_LEVEL": "info",
        "RAILS_MCP_MAX_RESULTS": "100"
      }
    }
  }
}
```

**Multiple Projects:**
```json
{
  "mcpServers": {
    "rails-project-1": {
      "command": "rails-active-mcp-server",
      "args": ["start", "--project", "/path/to/project1"]
    },
    "rails-project-2": {
      "command": "rails-active-mcp-server",
      "args": ["start", "--project", "/path/to/project2"]
    }
  }
}
```

### VS Code (with MCP Extension)

```json
{
  "mcp.servers": {
    "rails-active-mcp": {
      "command": "rails-active-mcp-server",
      "args": ["start", "--auto-detect"],
      "cwd": "${workspaceFolder}"
    }
  }
}
```

### Other MCP Clients

Rails Active MCP works with any MCP-compatible client. Use the command:

```bash
rails-active-mcp-server start [options]
```

## 🛠️ Available MCP Tools

The Rails Active MCP server provides four powerful tools that appear automatically in MCP clients:

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

## 🔒 Safety Features

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

## 🔧 Troubleshooting

### Common Issues

#### "No Rails project found"

**Problem**: The server can't detect a Rails project.

**Solutions**:
1. Run from within a Rails project directory
2. Use `--project /path/to/rails/app` to specify explicitly
3. Use `--auto-detect` to search parent directories
4. Verify the directory contains `Gemfile` and `config/application.rb`

```bash
# Validate your project
rails-active-mcp-server validate_project --project /path/to/rails/app
```

#### "Rails environment failed to load"

**Problem**: Rails application won't start.

**Solutions**:
1. Check for missing dependencies: `bundle install`
2. Verify database connectivity: `rails db:migrate:status`
3. Check for syntax errors: `rails runner "puts 'OK'"`
4. Review logs in `log/rails_mcp_stderr.log`

```bash
# Debug Rails loading
RAILS_MCP_DEBUG=1 rails-active-mcp-server start --project /path/to/rails/app
```

#### "MCP SDK not available"

**Problem**: The MCP gem is missing.

**Solution**:
```bash
gem install mcp
# or add to Gemfile
gem 'mcp', '~> 0.1.0'
```

#### "Permission denied" errors

**Problem**: File system permissions prevent access.

**Solutions**:
1. Check directory permissions: `ls -la`
2. Ensure read access to Rails project files
3. Verify write access to log directory

#### Configuration not loading

**Problem**: Configuration files are ignored.

**Solutions**:
1. Check file format: `cat config/rails_active_mcp.json | jq .`
2. Verify file permissions: `ls -la config/rails_active_mcp.json`
3. Use `--dry-run` to see configuration sources

```bash
# Debug configuration loading
rails-active-mcp-server start --dry-run --project /path/to/rails/app
```

### Debug Mode

Enable debug mode for detailed logging:

```bash
RAILS_MCP_DEBUG=1 rails-active-mcp-server start --auto-detect
```

This will:
- Disable output redirection
- Show detailed error messages
- Log Rails loading process
- Display configuration sources

### Log Files

Check log files for detailed error information:

- **stderr log**: `log/rails_mcp_stderr.log`
- **Rails log**: `log/development.log` (or appropriate environment)


## 🧪 Development and Testing

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run integration tests
bundle exec rspec spec/integration/

# Run specific test file
bundle exec rspec spec/rails_active_mcp/configuration_spec.rb
```

### Testing CLI Commands

```bash
# Test project validation
rails-active-mcp-server validate_project --project .

# Test configuration generation
rails-active-mcp-server generate_config --project .

# Test dry-run mode
rails-active-mcp-server start --dry-run --project .
```

### Testing MCP Integration

```bash
# Test MCP server output
./bin/test-mcp-output

# Debug MCP communication
RAILS_MCP_DEBUG=1 rails-active-mcp-server start --project .
```

### Code Quality

```bash
# Run RuboCop
bundle exec rubocop

# Auto-correct issues
bundle exec rubocop --autocorrect
```

## 🏗️ Architecture

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

### CLI Architecture

The CLI is implemented using Thor in `lib/rails_active_mcp/cli.rb`:

- **Command Structure**: Organized subcommands with options
- **Project Detection**: Automatic Rails project discovery
- **Configuration Management**: Hierarchical configuration loading
- **Validation**: Comprehensive project validation

## 🤝 Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

### Development Setup

```bash
git clone https://github.com/goodpie/rails-active-mcp.git
cd rails-active-mcp
bundle install
bundle exec rspec
```

## 📄 License

The gem is available as open source under the [MIT License](https://opensource.org/licenses/MIT).

**Made with ❤️ for the Rails and AI community**
