# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.1.0] - 2026-02-09

### Changed

- Updated MCP Ruby SDK from v0.4.0 to v0.6.0
- Added server metadata (websiteUrl, description) for improved discoverability in Claude Desktop
- Cleaned up duplicate gem declarations in Gemfile

### Internal

- Leveraged MCP SDK v0.6.0 icon optimization (omit when nil/empty)
- Aligned with MCP SDK v0.5.0 serverInfo enhancements

### Migration

No breaking changes. Simply run `bundle update mcp` to upgrade.

## [3.0.0] - 2025-12-01

### Changed

- **BREAKING**: Updated to MCP Ruby SDK v0.4.0 (was v0.1.0)
- **BREAKING**: Requires Ruby >= 3.2.0 (was >= 3.1.0)
- **BREAKING**: Updated to MCP protocol version 2025-11-25
- Tool error responses now include `is_error: true` flag per MCP 2025-11-25 specification

### Fixed

- Input validation errors are now returned as Tool Execution Errors instead of Protocol Errors (MCP 2025-11-25 compliance)

### Migration Guide

For users upgrading from v2.x:

1. Ensure you are running Ruby 3.2.0 or higher
2. Run `bundle update rails-active-mcp` to update the gem and its dependencies
3. No configuration changes are required

## [2.0.0] - 2025-01-15

### Added

- Official MCP Ruby SDK integration (`mcp` gem v0.1.0)
- Professional protocol handling with built-in instrumentation
- Automatic timing and error reporting
- Standards-compliant MCP protocol implementation
- Future-proof architecture with automatic SDK updates
- Enhanced error handling and comprehensive reporting
- Simplified tool names (removed `rails_` prefix)
- Updated documentation reflecting new architecture

### Changed

- **BREAKING**: Migrated from custom MCP server to official MCP Ruby SDK
- **BREAKING**: Simplified configuration options (removed complex server modes)
- **BREAKING**: Tool names updated:
  - `rails_console_execute` → `console_execute`
  - `rails_model_info` → `model_info`
  - `rails_safe_query` → `safe_query`
  - `rails_dry_run` → `dry_run`
- **BREAKING**: Removed HTTP server mode (STDIO only for Claude Desktop)
- **BREAKING**: Removed feature flag system (SDK implementation only)
- Server implementation moved to `lib/rails_active_mcp/sdk/server.rb`
- Tool implementations moved to `lib/rails_active_mcp/sdk/tools/`
- Updated README and documentation for new architecture

### Removed

- **BREAKING**: Custom MCP server implementation (799 lines of code)
- **BREAKING**: Legacy tool implementations
- **BREAKING**: Complex configuration options:
  - `server_mode`, `server_host`, `server_port`
  - `allowed_models`, `blocked_models`
  - `enable_mutation_tools`
  - Environment presets (`production_mode!`, `strict_mode!`, etc.)
- **BREAKING**: HTTP server mode and Rails mounting
- **BREAKING**: Feature flag system (`use_mcp_sdk`)
- Legacy files:
  - `lib/rails_active_mcp/mcp_server.rb`
  - `lib/rails_active_mcp/stdio_server.rb`
  - `lib/rails_active_mcp/application_mcp_tool.rb`
  - `lib/rails_active_mcp/tool_registry.rb`
  - `lib/rails_active_mcp/tools/` (legacy implementations)

### Performance

- 85% reduction in MCP protocol handling code
- Improved protocol performance through official SDK
- Better memory usage and resource management
- Faster tool execution with reduced overhead

### Security

- Maintained all existing safety features
- Enhanced error reporting without exposing internals
- Professional protocol handling reduces attack surface
- Continued comprehensive audit logging

### Migration Guide

For users upgrading from v1.x:

1. Update your `config/initializers/rails_active_mcp.rb` to use the simplified configuration
2. Update Claude Desktop configuration to remove any HTTP-specific settings
3. Tool names in your MCP client integrations need to be updated (remove `rails_` prefix)
4. The server now only supports STDIO mode (perfect for Claude Desktop)

## [0.1.0] - 2025-06-25

### Added

- Initial release of Rails Active MCP gem
- Core MCP tools for Rails console access:
    - `console_execute`: Execute Ruby code with safety checks
    - `safe_query`: Execute read-only database queries
    - `dry_run`: Analyze code safety without execution
    - `model_info`: Get model schema and associations
- Advanced safety checking system:
    - Pattern-based dangerous operation detection
    - Configurable safety levels (critical, high, medium, low)
    - Read-only operation detection
    - Custom safety pattern support
- Comprehensive configuration system:
    - Environment-specific presets (production, development, test)
    - Model access control (allow/block lists)
    - Timeout and result limiting
    - Audit logging configuration
- Rails integration:
    - Rails engine for automatic setup
    - Generator for easy installation
    - Rake tasks for management and testing
    - Active MCP integration
- Security features:
    - Execution timeout protection
    - Result size limiting
    - Complete audit logging
    - Environment-based safety modes
- Console executor with:
    - Output capturing
    - Error handling
    - Execution timing
    - Context isolation

### Security

- All dangerous operations blocked by default in safe mode
- Production mode enables strictest safety settings
- Comprehensive audit logging for security monitoring
- Model access restrictions to prevent unauthorized data access

## [0.0.1] - 2025-01-14

### Added

- Project initialization
- Basic gem structure
- Initial safety checker implementation