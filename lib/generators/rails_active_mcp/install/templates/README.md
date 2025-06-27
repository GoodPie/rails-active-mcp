# Rails Active MCP Integration

This Rails application is configured with Rails Active MCP for secure AI-powered database querying and model inspection.

## What is Rails Active MCP?

Rails Active MCP enables secure Rails console access through Model Context Protocol (MCP) for AI agents and development tools like Claude Desktop. It provides four main tools:

- **console_execute**: Execute Ruby/Rails code with safety checks
- **model_info**: Inspect Rails models (schema, associations, validations)
- **safe_query**: Run read-only database queries
- **dry_run**: Analyze code safety without execution

## Quick Start

### 1. Test the Installation

```bash
# Test the server starts correctly
bin/rails-active-mcp-wrapper

# Enable debug mode for troubleshooting
RAILS_MCP_DEBUG=1 bin/rails-active-mcp-server
```

### 2. Configure Claude Desktop

Add this to your Claude Desktop configuration:

**macOS/Linux**: `~/.config/claude-desktop/claude_desktop_config.json`
**Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "rails-active-mcp": {
      "command": "/path/to/your/rails/app/bin/rails-active-mcp-wrapper",
      "cwd": "/path/to/your/rails/app",
      "env": {
        "RAILS_ENV": "development"
      }
    }
  }
}
```

### 3. Try These Commands in Claude Desktop

- "Show me the User model structure"
- "How many users were created in the last week?"
- "What are the most recent orders?"
- "Check if this code is safe: `User.delete_all`"

## Configuration

Your MCP integration is configured in `config/initializers/rails_active_mcp.rb`.

### Environment-Specific Settings

- **Development**: More permissive, verbose logging
- **Production**: Strict safety, limited results, audit logging
- **Test**: Minimal logging, safety enabled

### Customizing Safety Rules

```ruby
# Add custom safety patterns
config.custom_safety_patterns = [
  { pattern: /YourDangerousMethod/, description: "Custom dangerous operation" }
]

# Restrict model access (empty = allow all)
config.allowed_models = %w[User Post Comment]
```

## Available Rake Tasks

```bash
# Check code safety
rails rails_active_mcp:check_safety['User.count']

# Execute code with safety checks  
rails rails_active_mcp:execute['User.count']

# Test MCP tools
rails rails_active_mcp:test_tools
```

## Troubleshooting

### Server Won't Start
- Ensure your Rails app starts without errors: `rails console`
- Check Ruby version compatibility
- Verify all gems are installed: `bundle install`

### Claude Desktop Connection Issues
- Restart Claude Desktop after configuration changes
- Check logs: `~/Library/Logs/Claude/mcp*.log` (macOS)
- Test server manually: `bin/rails-active-mcp-wrapper`

### Permission Errors
- Ensure wrapper script is executable: `chmod +x bin/rails-active-mcp-wrapper`
- Check Ruby path in wrapper script matches your setup

## Security Notes

- All dangerous operations are blocked by default in safe mode
- Production mode enables the strictest safety settings
- All executions can be logged for audit purposes
- Model access can be restricted via configuration

## Examples

### Safe Operations (Always Allowed)
```ruby
User.count
Post.where(published: true).limit(10)
User.find(1).posts.includes(:comments)
Rails.env
```

### Risky Operations (Blocked in Safe Mode)
```ruby
User.delete_all        # Mass deletion
system('rm -rf /')     # System commands
eval(user_input)       # Code evaluation
File.delete('file')    # File operations
```

## Getting Help

- **Documentation**: https://github.com/goodpie/rails-active-mcp
- **Issues**: https://github.com/goodpie/rails-active-mcp/issues
- **MCP Protocol**: https://modelcontextprotocol.io