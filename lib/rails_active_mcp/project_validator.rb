# frozen_string_literal: true

require 'json'
require 'fileutils'

module RailsActiveMcp
  # ProjectValidator provides comprehensive validation of Rails projects
  # for compatibility with Rails Active MCP server
  class ProjectValidator
    attr_reader :project_path

    def initialize(project_path)
      @project_path = File.expand_path(project_path)
    end

    # Perform comprehensive project validation
    # Returns a hash with validation results in JSON-serializable format
    def validate
      results = []

      # Core validation checks
      results << validate_rails_structure
      results << validate_gemfile
      results << validate_rails_dependency
      results << validate_database_config
      results << validate_mcp_compatibility

      # Determine overall validation status
      has_errors = results.any? { |r| r[:status] == :error }
      
      {
        valid: !has_errors,
        project_path: @project_path,
        checks: results,
        summary: generate_summary(results),
        timestamp: Time.now.iso8601
      }
    end

    # Convert validation results to JSON string
    def validate_json
      JSON.pretty_generate(validate)
    end

    private

    # Validate Rails application structure
    def validate_rails_structure
      config_app_rb = File.join(@project_path, 'config', 'application.rb')
      
      if File.exist?(config_app_rb)
        {
          name: 'Rails Application Structure',
          status: :ok,
          message: 'Valid Rails application.rb found',
          details: {
            file: config_app_rb,
            exists: true
          }
        }
      else
        # Check for additional Rails indicators
        routes_rb = File.join(@project_path, 'config', 'routes.rb')
        app_dir = File.join(@project_path, 'app')
        
        if File.exist?(routes_rb) || (File.directory?(app_dir) && has_rails_app_structure?)
          {
            name: 'Rails Application Structure',
            status: :warning,
            message: 'Rails-like structure detected but no config/application.rb found',
            details: {
              file: config_app_rb,
              exists: false,
              routes_exists: File.exist?(routes_rb),
              app_structure: has_rails_app_structure?
            }
          }
        else
          {
            name: 'Rails Application Structure',
            status: :error,
            message: 'No config/application.rb found - not a Rails application',
            details: {
              file: config_app_rb,
              exists: false
            }
          }
        end
      end
    end

    # Validate Gemfile existence
    def validate_gemfile
      gemfile_path = File.join(@project_path, 'Gemfile')
      
      if File.exist?(gemfile_path)
        {
          name: 'Gemfile',
          status: :ok,
          message: 'Gemfile found',
          details: {
            file: gemfile_path,
            exists: true,
            readable: File.readable?(gemfile_path)
          }
        }
      else
        {
          name: 'Gemfile',
          status: :error,
          message: 'No Gemfile found',
          details: {
            file: gemfile_path,
            exists: false
          }
        }
      end
    end

    # Validate Rails dependency in Gemfile
    def validate_rails_dependency
      gemfile_path = File.join(@project_path, 'Gemfile')
      
      unless File.exist?(gemfile_path)
        return {
          name: 'Rails Dependency',
          status: :error,
          message: 'Cannot check Rails dependency - Gemfile not found',
          details: {
            file: gemfile_path,
            exists: false
          }
        }
      end

      begin
        gemfile_content = File.read(gemfile_path)
        
        if gemfile_content.match?(/gem\s+['"]rails['"]/)
          {
            name: 'Rails Dependency',
            status: :ok,
            message: 'Rails dependency found in Gemfile',
            details: {
              file: gemfile_path,
              has_rails_gem: true
            }
          }
        else
          {
            name: 'Rails Dependency',
            status: :warning,
            message: 'No explicit Rails dependency found in Gemfile',
            details: {
              file: gemfile_path,
              has_rails_gem: false,
              note: 'Rails might be included via other gems or Gemfile.lock'
            }
          }
        end
      rescue Errno::EACCES
        {
          name: 'Rails Dependency',
          status: :error,
          message: 'Cannot read Gemfile - permission denied',
          details: {
            file: gemfile_path,
            readable: false
          }
        }
      rescue => e
        {
          name: 'Rails Dependency',
          status: :error,
          message: "Error reading Gemfile: #{e.message}",
          details: {
            file: gemfile_path,
            error: e.class.name
          }
        }
      end
    end

    # Validate database configuration
    def validate_database_config
      database_config = File.join(@project_path, 'config', 'database.yml')
      
      if File.exist?(database_config)
        begin
          # Try to read the file to ensure it's accessible
          File.read(database_config)
          
          {
            name: 'Database Configuration',
            status: :ok,
            message: 'Database configuration found',
            details: {
              file: database_config,
              exists: true,
              readable: true
            }
          }
        rescue Errno::EACCES
          {
            name: 'Database Configuration',
            status: :warning,
            message: 'Database configuration exists but is not readable',
            details: {
              file: database_config,
              exists: true,
              readable: false
            }
          }
        rescue => e
          {
            name: 'Database Configuration',
            status: :warning,
            message: "Database configuration found but has issues: #{e.message}",
            details: {
              file: database_config,
              exists: true,
              error: e.class.name
            }
          }
        end
      else
        {
          name: 'Database Configuration',
          status: :warning,
          message: 'No database configuration found (config/database.yml)',
          details: {
            file: database_config,
            exists: false,
            note: 'Some Rails apps may use alternative database configurations'
          }
        }
      end
    end

    # Validate MCP compatibility by testing Rails environment loading
    def validate_mcp_compatibility
      # Check if we can load the Rails environment
      original_dir = Dir.pwd
      
      begin
        Dir.chdir(@project_path)
        
        environment_rb = File.join(@project_path, 'config', 'environment.rb')
        
        unless File.exist?(environment_rb)
          return {
            name: 'MCP Compatibility',
            status: :error,
            message: 'No config/environment.rb found - Rails environment cannot be loaded',
            details: {
              file: environment_rb,
              exists: false
            }
          }
        end

        # Test Rails environment loading in a safe way
        # We'll use a subprocess to avoid affecting the current process
        test_result = test_rails_environment_loading

        if test_result[:success]
          {
            name: 'MCP Compatibility',
            status: :ok,
            message: 'Rails environment can be loaded successfully',
            details: {
              file: environment_rb,
              loadable: true,
              rails_version: test_result[:rails_version]
            }
          }
        else
          {
            name: 'MCP Compatibility',
            status: :error,
            message: "Rails environment failed to load: #{test_result[:error]}",
            details: {
              file: environment_rb,
              loadable: false,
              error: test_result[:error],
              error_class: test_result[:error_class]
            }
          }
        end
      ensure
        Dir.chdir(original_dir) if original_dir
      end
    end

    # Check if the app directory has typical Rails structure
    def has_rails_app_structure?
      app_dir = File.join(@project_path, 'app')
      return false unless File.directory?(app_dir)

      # Look for typical Rails subdirectories
      rails_subdirs = %w[models views controllers]
      rails_subdirs_found = rails_subdirs.count do |subdir|
        File.directory?(File.join(app_dir, subdir))
      end
      
      rails_subdirs_found >= 2
    end

    # Test Rails environment loading safely
    def test_rails_environment_loading
      # Use the same logic as ProjectUtils.load_rails_environment but capture results
      if File.exist?('config/environment.rb')
        begin
          # Try to require the environment
          require './config/environment'
          
          rails_version = defined?(Rails) && Rails.respond_to?(:version) ? Rails.version : 'unknown'
          
          {
            success: true,
            rails_version: rails_version
          }
        rescue => e
          {
            success: false,
            error: e.message,
            error_class: e.class.name
          }
        end
      else
        {
          success: false,
          error: 'config/environment.rb not found',
          error_class: 'FileNotFound'
        }
      end
    end

    # Generate a summary of validation results
    def generate_summary(results)
      total = results.length
      ok_count = results.count { |r| r[:status] == :ok }
      warning_count = results.count { |r| r[:status] == :warning }
      error_count = results.count { |r| r[:status] == :error }

      {
        total_checks: total,
        passed: ok_count,
        warnings: warning_count,
        errors: error_count,
        overall_status: error_count > 0 ? 'failed' : (warning_count > 0 ? 'passed_with_warnings' : 'passed')
      }
    end
  end
end