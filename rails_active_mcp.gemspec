# frozen_string_literal: true

require_relative 'lib/rails_active_mcp/version'

Gem::Specification.new do |spec|
  spec.name = 'rails-active-mcp'
  spec.version = RailsActiveMcp::VERSION
  spec.authors = ['Brandyn Britton']
  spec.email = ['brandynbb96@gmail.com']

  spec.summary = 'Globally installable, secure Rails console access via Model Context Protocol (MCP)'
  spec.description = <<~DESC
    Rails Active MCP enables secure Rails console access through Model Context Protocol (MCP)#{' '}
    for AI agents and development tools like Claude Desktop. Install globally and use with any#{' '}
    Rails project through auto-detection. Provides safe database querying, model introspection,#{' '}
    and code execution with comprehensive safety checks and audit logging.

    BREAKING CHANGES in v3.0+:
    • Removed backward compatibility with legacy stdio mode
    • Now requires explicit Thor CLI commands (start, generate_config, validate_project)
    • Simplified configuration and logging system
    • No longer supports running without command arguments

    Features include:
    • Global installation with automatic Rails project detection
    • Thor-based CLI with comprehensive help system
    • Safe Ruby code execution with configurable safety checks
    • Read-only database query tools with result limiting
    • Rails model introspection (schema, associations, validations)
    • Dry-run code analysis for safety validation
    • Environment-specific configuration presets
    • Comprehensive audit logging and monitoring
    • Claude Desktop integration out of the box
  DESC

  spec.homepage = 'https://github.com/goodpie/rails-active-mcp'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata = {
    'homepage_uri' => spec.homepage,
    'source_code_uri' => "#{spec.homepage}/tree/main",
    'changelog_uri' => "#{spec.homepage}/blob/main/changelog.md",
    'bug_tracker_uri' => "#{spec.homepage}/issues",
    'documentation_uri' => "#{spec.homepage}#readme",
    'wiki_uri' => "#{spec.homepage}/wiki",
    'mailing_list_uri' => "#{spec.homepage}/discussions",
    'funding_uri' => 'https://github.com/sponsors/goodpie',
    'rubygems_mfa_required' => 'true'
  }

  # Specify which files should be added to the gem when it is released
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile]) ||
        f.match?(%r{\A(?:log|tmp|\.)/}) ||
        f.end_with?('.log', '.tmp')
    end
  end + [
    'examples/rails_app_integration.md',
    'docs/DEBUGGING.md',
    'docs/README.md'
  ].select { |f| File.exist?(f) }

  spec.bindir = 'exe'
  spec.executables = ['rails-active-mcp-server']
  spec.require_paths = ['lib']

  # Runtime dependencies - more flexible Rails version support
  spec.add_dependency 'concurrent-ruby', '~> 1.3'
  spec.add_dependency 'rails', '>= 6.1', '< 9.0'

  # MCP SDK - Core protocol implementation
  spec.add_dependency 'mcp', '~> 0.1.0'

  # CLI framework for global installation
  spec.add_dependency 'thor', '~> 1.3'

  # Core dependencies
  spec.add_dependency 'json', '~> 2.0'
  spec.add_dependency 'rack', '>= 2.0', '< 4.0'
  spec.add_dependency 'timeout', '~> 0.4'
  spec.add_dependency 'webrick', '~> 1.8'

  # Development dependencies - keep versions consistent with Gemfile
  spec.add_development_dependency 'colorize', '~> 0.8'
  spec.add_development_dependency 'factory_bot_rails', '~> 6.0'
  spec.add_development_dependency 'faker', '~> 2.19'
  spec.add_development_dependency 'rspec', '~> 3.1'
  spec.add_development_dependency 'rspec-rails', '~> 6.0'
  spec.add_development_dependency 'rubocop', '~> 1.77'
  spec.add_development_dependency 'rubocop-rails', '~> 2.32'
  spec.add_development_dependency 'rubocop-rspec', '~> 3.0'
  spec.add_development_dependency 'sqlite3', '~> 2.7'

  # Post-install message to help users get started
  spec.post_install_message = <<~MSG

    🎉 Thanks for installing Rails Active MCP!

    Quick Start (Global Installation):
    1. Start the server: rails-active-mcp-server start --auto-detect
    2. Configure Claude Desktop with: "command": "rails-active-mcp-server"
    3. Run from any Rails project directory for automatic detection

    Global Usage:
    • rails-active-mcp-server start --help  # View all options
    • rails-active-mcp-server start --project /path/to/rails/app  # Explicit path
    • rails-active-mcp-server start --auto-detect --safe-mode  # Auto-detect with safety

    📚 Documentation: #{spec.homepage}#readme
    🐛 Issues: #{spec.homepage}/issues 
    💬 Discussions: #{spec.homepage}/discussions

    Follow the project: ⭐ #{spec.homepage}

  MSG
end
