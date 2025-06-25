# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-01-15

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