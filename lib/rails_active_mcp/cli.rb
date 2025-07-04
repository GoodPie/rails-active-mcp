# frozen_string_literal: true

require 'thor'
require 'json'
require 'fileutils'

module RailsActiveMcp
  # Rails project detection and validation utilities
  module ProjectUtils
    def self.find_rails_root(start_dir = Dir.pwd)
      current_dir = File.expand_path(start_dir)

      # Validate starting directory exists and is readable
      unless File.directory?(current_dir) && File.readable?(current_dir)
        return nil
      end

      # Traverse upward until we find Rails project or hit filesystem root
      loop do
        return current_dir if rails_project?(current_dir)

        parent_dir = File.dirname(current_dir)
        break if parent_dir == current_dir # Reached filesystem root

        current_dir = parent_dir

        # Safety check: ensure we can read the parent directory
        break unless File.readable?(current_dir)
      end

      nil
    end

    # Enhanced Rails project root detection (alias for consistency)
    def self.find_rails_project_root(start_dir = Dir.pwd)
      find_rails_root(start_dir)
    end

    def self.rails_project?(path)
      return false unless File.directory?(path) && File.readable?(path)

      # Primary indicator: Rails application file
      rails_app_rb = File.join(path, 'config', 'application.rb')
      return true if File.exist?(rails_app_rb)

      # Secondary indicator: Gemfile with Rails dependency
      gemfile_path = File.join(path, 'Gemfile')
      if File.exist?(gemfile_path)
        begin
          gemfile_content = File.read(gemfile_path)
          return true if gemfile_content.match?(/gem\s+['"]rails['"]/)
        rescue Errno::EACCES, Errno::ENOENT
          # Cannot read Gemfile, continue with other checks
        end
      end

      # Additional indicators for edge cases
      # Check for config/routes.rb (Rails-specific routing file)
      routes_rb = File.join(path, 'config', 'routes.rb')
      return true if File.exist?(routes_rb)

      # Check for app/ directory structure (typical Rails layout)
      app_dir = File.join(path, 'app')
      if File.directory?(app_dir)
        # Look for typical Rails subdirectories
        rails_subdirs = %w[models views controllers]
        rails_subdirs_found = rails_subdirs.count do |subdir|
          File.directory?(File.join(app_dir, subdir))
        end
        return true if rails_subdirs_found >= 2
      end

      # Check for Rakefile with Rails tasks
      rakefile_path = File.join(path, 'Rakefile')
      if File.exist?(rakefile_path)
        begin
          rakefile_content = File.read(rakefile_path)
          return true if rakefile_content.match?(/require.*rails/i)
        rescue Errno::EACCES, Errno::ENOENT
          # Cannot read Rakefile, not a strong indicator anyway
        end
      end

      false
    end

    # Determine Rails project path based on CLI options with robust error handling
    def self.determine_rails_path(options = {})
      if options[:project]
        # Explicit path provided - validate and expand it
        explicit_path = validate_project_path(options[:project])
        return explicit_path if explicit_path && rails_project?(explicit_path)

        # Path provided but not a Rails project
        return nil
      elsif options[:auto_detect]
        # Search upward from current directory
        find_rails_project_root(Dir.pwd)
      else
        # Default behavior: current directory if Rails project, otherwise search upward
        current_dir = Dir.pwd
        if rails_project?(current_dir)
          current_dir
        else
          find_rails_project_root(current_dir)
        end
      end
    end

    # Validate and expand project path with security checks
    def self.validate_project_path(path)
      return nil if path.nil? || path.empty?

      begin
        expanded_path = File.expand_path(path)

        # Check if path exists and is a directory
        return nil unless File.exist?(expanded_path) && File.directory?(expanded_path)

        # Check if path is readable
        return nil unless File.readable?(expanded_path)

        expanded_path
      rescue ArgumentError, SystemCallError
        # Invalid path or permission issues
        nil
      end
    end

    def self.load_rails_environment(project_path)
      rails_loaded = false
      rails_load_error = nil

      # Change to project directory
      original_dir = Dir.pwd
      Dir.chdir(project_path)

      if File.exist?('config/environment.rb')
        begin
          require './config/environment'
          rails_loaded = true
        rescue StandardError => e
          # Rails loading failed, continue without it
          rails_load_error = e
          warn "WARNING: Failed to load Rails environment: #{e.message}" if ENV['RAILS_MCP_DEBUG']
        end
      end

      [rails_loaded, rails_load_error]
    ensure
      # Always return to original directory
      Dir.chdir(original_dir) if original_dir
    end
  end

  # Thor CLI implementation
  class CLI < Thor
    package_name "rails-active-mcp-server"

    # Handle Thor deprecation warning
    def self.exit_on_failure?
      true
    end

    class_option :project, aliases: '-p', type: :string,
                 desc: 'Explicit Rails project path'
    class_option :auto_detect, aliases: '-a', type: :boolean,
                 desc: 'Auto-detect Rails project from current directory'
    class_option :safe_mode, type: :boolean, default: true,
                 desc: 'Enable safe mode (blocks dangerous operations)'
    class_option :timeout, type: :numeric, default: 30,
                 desc: 'Command timeout in seconds'
    class_option :log_level, type: :string, default: 'info',
                 desc: 'Log level: debug, info, warn, error'
    class_option :dry_run, type: :boolean,
                 desc: 'Show configuration without starting server'

    desc "start", "Start the Rails Active MCP server"
    long_desc <<-LONGDESC
      Start the Rails Active MCP server for the specified or auto-detected Rails project.

      This command starts the MCP server using stdio transport for integration with
      AI agents like Claude Desktop. The server provides secure Rails console access,
      database querying, and model introspection capabilities.

      Examples:
      \x5 rails-active-mcp-server start --auto-detect
      \x5 rails-active-mcp-server start --project /path/to/rails/app
      \x5 rails-active-mcp-server start --dry-run  # Show config without starting
      \x5 rails-active-mcp-server start --safe-mode --timeout 60
    LONGDESC

    def start
      project_path = determine_project_path

      unless project_path
        say "Error: No Rails project found.", :red
        say "Use --project PATH or --auto-detect, or run from within a Rails project."
        exit 1
      end

      unless ProjectUtils.rails_project?(project_path)
        say "Error: #{project_path} is not a Rails project.", :red
        exit 1
      end

      # Build configuration
      config = build_configuration

      # Handle dry-run mode
      if options[:dry_run]
        display_configuration(config, project_path)
        return
      end

      # Start server
      start_server(config, project_path)
    end

    desc "generate_config", "Generate configuration file for the current project"
    long_desc <<-LONGDESC
      Generate a JSON configuration file for the Rails Active MCP server.

      This creates a rails_active_mcp.json file in the config/ directory of your
      Rails project with default settings that can be customized.

      Examples:
      \x5 rails-active-mcp-server generate_config
      \x5 rails-active-mcp-server generate_config --project /path/to/rails/app
    LONGDESC

    def generate_config
      project_path = determine_project_path

      unless project_path
        say "Error: No Rails project found.", :red
        say "Use --project PATH or --auto-detect, or run from within a Rails project."
        exit 1
      end

      unless ProjectUtils.rails_project?(project_path)
        say "Error: #{project_path} is not a Rails project.", :red
        exit 1
      end

      config_file = File.join(project_path, 'config', 'rails_active_mcp.json')

      if File.exist?(config_file)
        say "Configuration file already exists: #{config_file}", :yellow
        return unless yes?("Overwrite existing configuration? (y/n)")
      end

      # Generate default configuration
      default_config = {
        safe_mode: true,
        command_timeout: 30,
        log_level: 'info',
        enable_logging: true,
        max_results: 100,
        allowed_commands: %w[
          ls pwd cat head tail grep find wc
          rails console rails runner
          bundle exec rspec bundle exec test
          git status git log git diff
        ],
        blocked_patterns: %w[*.delete_all *.destroy_all system exec `],
        allowed_models: []
      }

      File.write(config_file, JSON.pretty_generate(default_config))
      say "Generated configuration file: #{config_file}", :green
      say "Edit this file to customize your Rails Active MCP settings."
    end

    desc "validate_project", "Validate Rails project compatibility"
    long_desc <<-LONGDESC
      Validate that a Rails project is compatible with Rails Active MCP.

      This command checks the project structure, dependencies, and configuration
      to ensure the MCP server can run successfully.

      Examples:
      \x5 rails-active-mcp-server validate_project
      \x5 rails-active-mcp-server validate_project --project /path/to/rails/app
    LONGDESC

    def validate_project
      project_path = determine_project_path

      unless project_path
        say "Error: No Rails project found.", :red
        say "Use --project PATH or --auto-detect, or run from within a Rails project."
        exit 1
      end

      say "Validating Rails project: #{project_path}", :blue
      say ""

      # Validate Rails structure
      if ProjectUtils.rails_project?(project_path)
        say "✓ Valid Rails project structure", :green
      else
        say "✗ Invalid Rails project structure", :red
        exit 1
      end

      # Check Gemfile
      gemfile_path = File.join(project_path, 'Gemfile')
      if File.exist?(gemfile_path)
        say "✓ Gemfile found", :green

        gemfile_content = File.read(gemfile_path)
        if gemfile_content.match?(/gem\s+['"]rails['"]/)
          say "✓ Rails dependency found in Gemfile", :green
        else
          say "⚠ No explicit Rails dependency in Gemfile", :yellow
        end
      else
        say "✗ No Gemfile found", :red
      end

      # Check database configuration
      database_config = File.join(project_path, 'config', 'database.yml')
      if File.exist?(database_config)
        say "✓ Database configuration found", :green
      else
        say "⚠ No database configuration found", :yellow
      end

      # Test Rails environment loading
      say "Testing Rails environment loading...", :blue
      rails_loaded, rails_error = ProjectUtils.load_rails_environment(project_path)

      if rails_loaded
        say "✓ Rails environment loads successfully", :green
      else
        say "✗ Rails environment failed to load: #{rails_error&.message}", :red
      end

      say ""
      say "Project validation complete!", :green
    end

    private

    def determine_project_path
      # Use enhanced project detection with robust error handling
      ProjectUtils.determine_rails_path(options)
    end

    def build_configuration
      config = RailsActiveMcp::Configuration.new

      # Apply CLI options
      config.safe_mode = options[:safe_mode] if options.key?(:safe_mode)
      config.command_timeout = options[:timeout] if options[:timeout]
      config.log_level = options[:log_level].to_sym if options[:log_level]

      config
    end

    def display_configuration(config, project_path)
      say "Rails Active MCP Server Configuration", :blue
      say "=" * 40
      say "Rails Project: #{project_path}"
      say "Safe Mode: #{config.safe_mode}"
      say "Command Timeout: #{config.command_timeout}s"
      say "Log Level: #{config.log_level}"
      say "Max Results: #{config.max_results}"
      say ""
      say "Server would start with these settings.", :green
    end

    def start_server(config, project_path)
      # Setup stdio redirection for MCP communication (only redirect stderr for logging)
      unless ENV['RAILS_MCP_DEBUG']
        # Create log directory
        log_dir = File.join(project_path, 'log')
        FileUtils.mkdir_p(log_dir)

        # Redirect stderr to log file
        stderr_log = File.join(log_dir, 'rails_mcp_stderr.log')
        $stderr.reopen(stderr_log, 'a')
        $stderr.sync = true
      end

      # Load Rails environment
      rails_loaded, rails_load_error = ProjectUtils.load_rails_environment(project_path)

      # Start MCP server
      begin
        require_relative 'sdk/server'

        # Log startup information to stderr (which goes to log file)
        warn "Starting Rails Active MCP Server v#{RailsActiveMcp::VERSION}"
        warn "Rails loaded: #{rails_loaded}"
        warn "Working directory: #{project_path}"

        if rails_load_error
          warn "Rails load error: #{rails_load_error.class.name}: #{rails_load_error.message}"
        end

        server = RailsActiveMcp::Sdk::Server.new
        server.run_stdio
      rescue Interrupt
        warn "Server interrupted by user"
        exit(0)
      rescue LoadError => e
        puts "FATAL: MCP SDK not available: #{e.message}"
        puts "Please install the MCP gem: gem install mcp"
        exit(1)
      rescue StandardError => e
        puts "FATAL: Server startup failed: #{e.message}"
        puts e.backtrace.join("\n") if ENV['RAILS_MCP_DEBUG']
        exit(1)
      end
    end
  end
end
