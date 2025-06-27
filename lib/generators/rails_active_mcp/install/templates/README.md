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

2. Configure server mode in config/initializers/rails_active_mcp.rb:
   config.server_mode = :stdio    # For Claude Desktop (default)
   config.server_mode = :http     # For HTTP-based integrations
   config.server_host = 'localhost'
   config.server_port = 3001

3. Start the MCP server:
   Option A: Use configured mode (RECOMMENDED)
   $ bundle exec rails-active-mcp-server

   Option B: Override mode via command line
   $ bundle exec rails-active-mcp-server stdio  # Force stdio mode
   $ bundle exec rails-active-mcp-server http   # Force HTTP mode

   Option C: Rails-mounted server (HTTP)
   $ rails server

   Option D: Using rackup
   $ rackup mcp.ru -p 3001

4. For Claude Desktop integration, add this to your Claude Desktop configuration:

   Location: ~/.config/claude-desktop/claude_desktop_config.json (Linux/macOS)
   Location: %APPDATA%\Claude\claude_desktop_config.json (Windows)

   {
     "mcpServers": {
       "rails-active-mcp": {
         "command": "<%= Rails.root %>/bin/rails-active-mcp-wrapper",
         "args": ["stdio"],
         "cwd": "<%= Rails.root %>", 
         "env": {
           "RAILS_ENV": "development",
           "HOME": "/Users/your-username"
         }
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

5. For other MCP clients (HTTP-based), add this to your MCP configuration:
   {
     "mcpServers": {
       "rails-console": {
         "command": "curl",
         "args": ["-X", "POST", "-H", "Content-Type: application/json", "-d", "@-", "http://localhost:3000/mcp"]
       }
     }
   }

6. Test the installation:
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

Configuration Examples:

For Claude Desktop (default):
  config.server_mode = :stdio

For HTTP web integrations:
  config.server_mode = :http
  config.server_host = 'localhost'
  config.server_port = 3001

For Docker/remote access:
  config.http_mode!(host: '0.0.0.0', port: 8080)

For development with multiple transport modes:
  if Rails.env.development?
    config.stdio_mode!  # Claude Desktop
  else
    config.http_mode!(host: '0.0.0.0', port: 3001)  # Production HTTP
  end

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

1. Ruby Version Manager Conflicts (Most Common Issue):
   If you see errors like "Could not find 'bundler' (X.X.X)" or "Your Ruby version is X.X.X, but your Gemfile specified Y.Y.Y":
   
   This happens because Claude Desktop uses system Ruby instead of your project's Ruby version.
   
   Solution A - Use the wrapper script (Recommended):
   In claude_desktop_config.json, use:
   "command": "<%= Rails.root %>/bin/rails-active-mcp-wrapper"
   
   Solution B - Create system symlink:
   $ sudo ln -sf $(which ruby) /usr/local/bin/ruby
   
   Solution C - Use absolute Ruby path:
   In claude_desktop_config.json, change "command" to your full Ruby path:
   "command": "$(which ruby)"
   "args": ["<%= Rails.root %>/bin/rails-active-mcp-server", "stdio"]

2. Environment Variable Issues:
   If you see "error loading config: $HOME is not defined":
   
   This happens because Claude Desktop doesn't inherit all environment variables.
   
   Solution: Add HOME to your env section in claude_desktop_config.json:
   "env": {
     "RAILS_ENV": "development",
     "HOME": "/Users/your-username"
   }

3. General Environment Issues:
   - Ensure your Rails environment loads properly in the project directory
   - Check that the gem is properly installed and configured  
   - Verify the Rails application starts without errors
   - Make sure the cwd path in Claude Desktop config is correct

4. Debug Steps:
   - Test manually: $ ./bin/rails-active-mcp-wrapper stdio
   - Should output JSON (not plain text)
   - Enable debug logging with RAILS_MCP_DEBUG=1 for detailed output
   - Check Claude logs: $ tail -f ~/Library/Logs/Claude/mcp*.log
   - Test environment variables: $ echo $HOME (should show your home directory)

For more information: https://github.com/goodpie/rails-active-mcp

================================================================================