# Rails Active MCP Debugging Guide

This guide covers debugging and troubleshooting for the Rails Active MCP server, following the [MCP debugging best practices](https://modelcontextprotocol.io/docs/tools/debugging).

## Quick Debug Commands

```bash
# Test with MCP Inspector (recommended)
bin/debug-mcp-server --mode inspector

# Enable debug logging
RAILS_MCP_DEBUG=1 bundle exec rails-active-mcp-server stdio

# View recent logs
bin/debug-mcp-server --mode logs

# Basic connectivity test
bin/debug-mcp-server --mode test
```

## Debug Tools Overview

### 1. MCP Inspector (Interactive Testing)

The MCP Inspector provides the best debugging experience for MCP servers:

```bash
# Launch inspector connected to your Rails MCP server
bin/debug-mcp-server --mode inspector

# Or manually:
npx @modelcontextprotocol/inspector bundle exec rails-active-mcp-server stdio
```

The Inspector provides:
- ✅ Interactive tool testing
- ✅ Real-time message inspection
- ✅ Error visualization
- ✅ Request/response history
- ✅ Server capability discovery

### 2. Debug Logging

Enable detailed logging with the `RAILS_MCP_DEBUG` environment variable:

```bash
RAILS_MCP_DEBUG=1 bundle exec rails-active-mcp-server stdio
```

This enables:
- Request/response logging to stderr
- Tool execution timing
- Detailed error stack traces
- JSON-RPC message debugging

### 3. Claude Desktop Integration Debugging

#### Checking Server Status in Claude Desktop

1. Click the 🔌 icon to view connected servers
2. Click the "Search and tools" 🔍 icon to view available tools
3. Look for these Rails Active MCP tools:
   - `rails_console_execute`
   - `rails_model_info`
   - `rails_safe_query`
   - `rails_dry_run`

#### Viewing Claude Desktop Logs

```bash
# macOS
tail -f ~/Library/Logs/Claude/mcp*.log

# Alternative locations
ls ~/Library/Logs/Claude/
```

The logs show:
- Server connection events
- Configuration issues
- Runtime errors
- Tool execution logs

#### Using Chrome DevTools in Claude Desktop

1. Enable developer tools:
   ```bash
   echo '{"allowDevTools": true}' > ~/Library/Application\ Support/Claude/developer_settings.json
   ```

2. Open DevTools: `Command-Option-Shift-i`

3. Use Console and Network panels to inspect:
   - Client-side errors
   - Message payloads
   - Connection timing

## Common Issues and Solutions

### 1. Working Directory Issues

**Problem**: Server can't find Rails environment or files.

**Solution**: Always use absolute paths in Claude Desktop config:

```json
{
  "mcpServers": {
    "rails-active-mcp": {
      "command": "bundle",
      "args": ["exec", "rails-active-mcp-server", "stdio"],
      "cwd": "/absolute/path/to/your/rails/project"
    }
  }
}
```

### 2. Environment Variables

**Problem**: Rails environment or API keys not available.

**Solution**: Specify environment variables in config:

```json
{
  "mcpServers": {
    "rails-active-mcp": {
      "command": "bundle",
      "args": ["exec", "rails-active-mcp-server", "stdio"],
      "cwd": "/path/to/rails/project",
      "env": {
        "RAILS_ENV": "development",
        "RAILS_MCP_DEBUG": "1"
      }
    }
  }
}
```

### 3. Server Initialization Problems

**Common initialization issues:**

1. **Path Issues**
   ```bash
   # Test the command directly
   cd /path/to/rails/project
   bundle exec rails-active-mcp-server stdio
   ```

2. **Rails Environment Issues**
   ```bash
   # Verify Rails loads
   cd /path/to/rails/project
   bundle exec rails runner "puts 'Rails loaded successfully'"
   ```

3. **Permission Problems**
   ```bash
   # Check file permissions
   ls -la exe/rails-active-mcp-server
   chmod +x exe/rails-active-mcp-server
   ```

### 4. Connection Problems

**Problem**: Claude Desktop can't connect to server.

**Debug steps:**
1. Check Claude Desktop logs for errors
2. Test with MCP Inspector: `bin/debug-mcp-server --mode inspector`
3. Verify server process starts: `ps aux | grep rails-active-mcp`
4. Test basic JSON-RPC response:
   ```bash
   echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}' | bundle exec rails-active-mcp-server stdio
   ```

## Logging Implementation

### Server-Side Logging

The Rails Active MCP server implements comprehensive logging:

```ruby
# Logs to stderr (captured by Claude Desktop)
@logger = Logger.new(STDERR)
@logger.level = ENV['RAILS_MCP_DEBUG'] ? Logger::DEBUG : Logger::ERROR

# MCP log notifications (sent to client)
def send_log_notification(level, message)
  notification = {
    jsonrpc: JSONRPC_VERSION,
    method: 'notifications/message',
    params: { level: level, data: message }
  }
  puts notification.to_json
  STDOUT.flush
end
```

### Log Levels and Events

- **INFO**: Server startup, tool execution start/completion
- **ERROR**: Parse errors, tool execution failures, unexpected errors
- **DEBUG**: Request/response details, execution timing (when `RAILS_MCP_DEBUG=1`)

### Important Events Logged

1. **Initialization**: Server startup, tool registration
2. **Tool Execution**: Start time, completion time, success/failure
3. **Error Conditions**: Parse errors, execution failures, safety violations
4. **Performance**: Execution timing, request processing

## Testing Your Implementation

### Basic Connectivity Test

```bash
# Test initialize method
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}' | bundle exec rails-active-mcp-server stdio
```

Expected response:
```json
{
  "jsonrpc":"2.0",
  "id":1,
  "result": {
    "protocolVersion":"2025-06-18",
    "capabilities":{"tools":{},"resources":{}},
    "serverInfo":{"name":"rails-active-mcp","version":"..."}
  }
}
```

### Tools List Test

```bash
# Test tools/list method
echo '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' | bundle exec rails-active-mcp-server stdio
```

Should return all 4 Rails Active MCP tools.

### Tool Execution Test

```bash
# Test a simple tool call
echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"rails_dry_run","arguments":{"code":"puts \"Hello World\""}}}' | bundle exec rails-active-mcp-server stdio
```

## Best Practices

### Development Workflow

1. **Start with Inspector**: Use `bin/debug-mcp-server --mode inspector` for development
2. **Enable Debug Logging**: Use `RAILS_MCP_DEBUG=1` during development
3. **Test Integration**: Test in Claude Desktop with debug logs enabled
4. **Monitor Performance**: Check execution times and resource usage

### Security Considerations When Debugging

1. **Sanitize Logs**: Never log sensitive data (passwords, API keys)
2. **Limit Debug Info**: Don't expose internal system details in production
3. **Protect Credentials**: Use environment variables, not hardcoded values

### Performance Monitoring

- Monitor tool execution times
- Track memory usage during long operations
- Log slow queries and operations
- Monitor connection stability

## Getting Help

When reporting issues:

1. **Provide log excerpts** from both server and Claude Desktop
2. **Include configuration files** (sanitized)
3. **List steps to reproduce** the issue
4. **Specify environment details** (Ruby version, Rails version, OS)

### Support Resources

- [MCP Inspector Documentation](https://modelcontextprotocol.io/docs/tools/inspector)
- [MCP Debugging Guide](https://modelcontextprotocol.io/docs/tools/debugging)
- [GitHub Issues](https://github.com/goodpie/rails-active-mcp/issues)

## Advanced Debugging

### Custom Log Analysis

Monitor specific patterns in logs:

```bash
# Watch for tool executions
tail -f ~/Library/Logs/Claude/mcp*.log | grep "Executing tool"

# Monitor errors only
tail -f ~/Library/Logs/Claude/mcp*.log | grep "ERROR"

# Track performance
tail -f ~/Library/Logs/Claude/mcp*.log | grep "completed in"
```

### Development Tips

1. **Use Inspector First**: Always test changes with MCP Inspector before Claude Desktop
2. **Enable All Logging**: Use debug mode to see the full request/response cycle
3. **Test Edge Cases**: Invalid inputs, timeouts, concurrent requests
4. **Monitor Resource Usage**: Watch memory and CPU during development

This debugging guide ensures your Rails Active MCP server works reliably with Claude Desktop and other MCP clients. 