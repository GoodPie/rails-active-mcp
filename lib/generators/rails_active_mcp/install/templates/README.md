================================================================================
Rails Active MCP has been installed!
================================================================================

Configuration:
- Initializer created at: config/initializers/rails_active_mcp.rb
- Custom MCP server mounted at: /mcp
- MCP server configuration: mcp.ru
- Audit log will be created at: log/rails_active_mcp.log

Next Steps:

1. Review and customize the configuration in config/initializers/rails_active_mcp.rb

2. Start the MCP server:
   Option A: Rails-mounted server (HTTP)
   $ rails server

   Option B: Standalone HTTP server
   $ bundle exec rails-active-mcp-server http

   Option C: Using rackup
   $ rackup mcp.ru -p 3001

   Option D: Stdio server for Claude Desktop (RECOMMENDED)
   $ bundle exec rails-active-mcp-server stdio

3. For Claude Desktop integration, add this to your Claude Desktop configuration:

   Location: ~/.config/claude-desktop/claude_desktop_config.json (Linux/macOS)
   Location: %APPDATA%\Claude\claude_desktop_config.json (Windows)

   {
     "mcpServers": {
       "rails-active-mcp": {
         "command": "bundle",
         "args": ["exec", "rails-active-mcp-server", "stdio"],
         "cwd": "/path/to/your/rails/project"
       }
     }
   }

   OR if you've installed the gem globally:

   {
     "mcpServers": {
       "rails-active-mcp": {
         "command": "rails-active-mcp-server",
         "args": ["stdio"],
         "cwd": "/path/to/your/rails/project"
       }
     }
   }

4. For other MCP clients (HTTP-based), add this to your MCP configuration:
   {
     "mcpServers": {
       "rails-console": {
         "command": "curl",
         "args": ["-X", "POST", "-H", "Content-Type: application/json", "-d", "@-", "http://localhost:3000/mcp"]
       }
     }
   }

5. Test the installation:
   $ rails console
   > RailsActiveMcp.safe?("User.count")
   > RailsActiveMcp.execute("User.count")

Built-in Tools Available in Claude:
- rails_console_execute: Execute Ruby code in Rails console with safety checks
- rails_model_info: Get detailed information about Rails models
- rails_safe_query: Execute safe read-only database queries
- rails_dry_run: Analyze Ruby code for safety without execution

Extend with custom tools by modifying the MCP server implementation.

Security Notes:
- Production mode enables strict safety by default
- All executions are logged to the audit file
- Dangerous operations are blocked in safe mode
- Review the safety patterns in the configuration

Transport Modes:
- stdio: For Claude Desktop and compatible MCP clients (recommended)
- http: For HTTP-based integrations and web applications

Custom MCP Server Benefits:
- No external dependencies
- Full control over implementation
- Simplified deployment
- Enhanced security
- Works with Claude Desktop

Debugging and Troubleshooting:

For interactive debugging, use the MCP Inspector:
$ bin/debug-mcp-server --mode inspector

This will:
- Launch the MCP Inspector connected to your server
- Allow interactive testing of all tools
- Show real-time debug output and logs

Debug logging:
$ RAILS_MCP_DEBUG=1 bundle exec rails-active-mcp-server stdio

View Claude Desktop logs:
$ tail -f ~/Library/Logs/Claude/mcp*.log  # macOS
$ tail -f ~/.config/claude-desktop/logs/*.log  # Linux

Common issues:
- Ensure your Rails environment loads properly in the project directory
- Check that the gem is properly installed and configured  
- Verify the Rails application starts without errors
- Make sure the cwd path in Claude Desktop config is correct
- Enable debug logging with RAILS_MCP_DEBUG=1 for detailed output

For more information: https://github.com/goodpie/rails-active-mcp

================================================================================