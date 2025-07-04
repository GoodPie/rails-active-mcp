# frozen_string_literal: true

require 'fileutils'
require 'json'

module RailsActiveMcp
  class Configuration
    # Core configuration options
    attr_accessor :allowed_commands, :command_timeout, :enable_logging, :log_level

    # Safety and execution options
    attr_accessor :safe_mode, :max_results, :log_executions, :audit_file, :enabled
    attr_accessor :custom_safety_patterns, :allowed_models

    def initialize(project_path = nil)
      # Load defaults first
      load_defaults

      # Apply configuration hierarchy: defaults → global config → project config → env vars
      # CLI args are applied separately via merge! method
      load_global_config
      load_project_config(project_path) if project_path
      apply_environment_variables
    end

    def model_allowed?(model_name)
      return true if @allowed_models.empty? # Allow all if none specified

      @allowed_models.include?(model_name.to_s)
    end

    def valid?
      allowed_commands.is_a?(Array) &&
        command_timeout.is_a?(Numeric) && command_timeout > 0 &&
        [true, false].include?(enable_logging) &&
        %i[debug info warn error].include?(log_level) &&
        [true, false].include?(safe_mode) &&
        max_results.is_a?(Numeric) && max_results > 0 &&
        [true, false].include?(log_executions) &&
        custom_safety_patterns.is_a?(Array) &&
        allowed_models.is_a?(Array) &&
        [true, false].include?(enabled)
    end

    def validate?
      raise ArgumentError, 'allowed_commands must be an array' unless allowed_commands.is_a?(Array)

      raise ArgumentError, 'command_timeout must be positive' unless command_timeout.is_a?(Numeric) && command_timeout > 0

      raise ArgumentError, 'log_level must be one of: debug, info, warn, error' unless %i[debug info warn error].include?(log_level)

      raise ArgumentError, 'safe_mode must be a boolean' unless [true, false].include?(safe_mode)

      raise ArgumentError, 'max_results must be positive' unless max_results.is_a?(Numeric) && max_results > 0

      raise ArgumentError, 'enabled must be a boolean' unless [true, false].include?(enabled)

      true
    end

    def reset!
      initialize
    end

    # Convert configuration to hash for serialization and dry-run display
    def to_h
      {
        safe_mode: @safe_mode,
        command_timeout: @command_timeout,
        log_level: @log_level,
        enable_logging: @enable_logging,
        max_results: @max_results,
        log_executions: @log_executions,
        audit_file: @audit_file,
        enabled: @enabled,
        allowed_commands: @allowed_commands,
        custom_safety_patterns: @custom_safety_patterns,
        allowed_models: @allowed_models
      }
    end

    # Merge configuration from another source (CLI options, config files, etc.)
    def merge!(other_config)
      case other_config
      when Hash
        merge_hash!(other_config)
      when Configuration
        merge_configuration!(other_config)
      else
        raise ArgumentError, "Cannot merge configuration from #{other_config.class}"
      end
      self
    end

    private

    # Load default configuration values
    def load_defaults
      @allowed_commands = %w[
        ls pwd cat head tail grep find wc
        rails console rails runner
        bundle exec rspec bundle exec test
        git status git log git diff
      ]
      @command_timeout = 30
      @enable_logging = true
      @log_level = :info

      # Safety and execution defaults
      @safe_mode = true
      @max_results = 100
      @log_executions = false
      @audit_file = nil
      @custom_safety_patterns = []
      @allowed_models = []
      @enabled = true
    end

    # Load global configuration file from user's config directory
    def load_global_config
      global_config_file = global_config_path
      return unless File.exist?(global_config_file)

      load_json_config(global_config_file)
    rescue => e
      warn "Warning: Failed to load global config from #{global_config_file}: #{e.message}" if ENV['RAILS_MCP_DEBUG']
    end

    # Load project-specific configuration file
    def load_project_config(project_path)
      return unless project_path

      project_config_file = File.join(project_path, 'config', 'rails_active_mcp.json')
      return unless File.exist?(project_config_file)

      load_json_config(project_config_file)
    rescue => e
      warn "Warning: Failed to load project config from #{project_config_file}: #{e.message}" if ENV['RAILS_MCP_DEBUG']
    end

    # Apply environment variables with RAILS_MCP_ prefix
    def apply_environment_variables
      # Boolean environment variables
      apply_env_boolean('RAILS_MCP_SAFE_MODE', :@safe_mode)
      apply_env_boolean('RAILS_MCP_ENABLE_LOGGING', :@enable_logging)
      apply_env_boolean('RAILS_MCP_LOG_EXECUTIONS', :@log_executions)
      apply_env_boolean('RAILS_MCP_ENABLED', :@enabled)

      # Numeric environment variables
      apply_env_numeric('RAILS_MCP_TIMEOUT', :@command_timeout)
      apply_env_numeric('RAILS_MCP_MAX_RESULTS', :@max_results)

      # String environment variables
      apply_env_string('RAILS_MCP_LOG_LEVEL', :@log_level, %w[debug info warn error])
      apply_env_string('RAILS_MCP_AUDIT_FILE', :@audit_file)

      # Array environment variables (comma-separated)
      apply_env_array('RAILS_MCP_ALLOWED_COMMANDS', :@allowed_commands)
      apply_env_array('RAILS_MCP_CUSTOM_SAFETY_PATTERNS', :@custom_safety_patterns)
      apply_env_array('RAILS_MCP_ALLOWED_MODELS', :@allowed_models)
    end

    # Get global configuration file path
    def global_config_path
      if ENV['XDG_CONFIG_HOME']
        File.join(ENV['XDG_CONFIG_HOME'], 'rails_active_mcp', 'config.json')
      else
        File.expand_path('~/.config/rails_active_mcp/config.json')
      end
    end

    # Load and parse JSON configuration file
    def load_json_config(file_path)
      content = File.read(file_path)
      config_hash = JSON.parse(content, symbolize_names: true)
      merge_hash!(config_hash)
    rescue JSON::ParserError => e
      warn "Warning: Invalid JSON in config file #{file_path}: #{e.message}"
    rescue Errno::ENOENT
      # File doesn't exist, which is fine
    rescue Errno::EACCES => e
      warn "Warning: Cannot read config file #{file_path}: #{e.message}"
    end

    # Merge configuration from hash
    def merge_hash!(hash)
      hash.each do |key, value|
        case key.to_sym
        when :safe_mode
          @safe_mode = value if [true, false].include?(value)
        when :command_timeout
          @command_timeout = value if value.is_a?(Numeric) && value > 0
        when :log_level
          log_level_sym = value.to_sym if value.respond_to?(:to_sym)
          @log_level = log_level_sym if %i[debug info warn error].include?(log_level_sym)
        when :enable_logging
          @enable_logging = value if [true, false].include?(value)
        when :max_results
          @max_results = value if value.is_a?(Numeric) && value > 0
        when :log_executions
          @log_executions = value if [true, false].include?(value)
        when :audit_file
          @audit_file = value.to_s if value
        when :enabled
          @enabled = value if [true, false].include?(value)
        when :allowed_commands
          @allowed_commands = value if value.is_a?(Array)
        when :custom_safety_patterns
          @custom_safety_patterns = value if value.is_a?(Array)
        when :allowed_models
          @allowed_models = value if value.is_a?(Array)
        end
      end
    end

    # Merge configuration from another Configuration object
    def merge_configuration!(other_config)
      @safe_mode = other_config.safe_mode unless other_config.safe_mode.nil?
      @command_timeout = other_config.command_timeout unless other_config.command_timeout.nil?
      @log_level = other_config.log_level unless other_config.log_level.nil?
      @enable_logging = other_config.enable_logging unless other_config.enable_logging.nil?
      @max_results = other_config.max_results unless other_config.max_results.nil?
      @log_executions = other_config.log_executions unless other_config.log_executions.nil?
      @audit_file = other_config.audit_file unless other_config.audit_file.nil?
      @enabled = other_config.enabled unless other_config.enabled.nil?
      @allowed_commands = other_config.allowed_commands unless other_config.allowed_commands.nil?
      @custom_safety_patterns = other_config.custom_safety_patterns unless other_config.custom_safety_patterns.nil?
      @allowed_models = other_config.allowed_models unless other_config.allowed_models.nil?
    end

    # Apply boolean environment variable
    def apply_env_boolean(env_var, instance_var)
      return unless ENV.key?(env_var)

      value = ENV[env_var].downcase
      instance_variable_set(instance_var, value == 'true') if %w[true false].include?(value)
    end

    # Apply numeric environment variable
    def apply_env_numeric(env_var, instance_var)
      return unless ENV[env_var]

      value = ENV[env_var].to_i
      instance_variable_set(instance_var, value) if value > 0
    end

    # Apply string environment variable with optional validation
    def apply_env_string(env_var, instance_var, valid_values = nil)
      return unless ENV[env_var]

      value = ENV[env_var]
      if valid_values
        value_sym = value.to_sym
        instance_variable_set(instance_var, value_sym) if valid_values.include?(value)
      else
        instance_variable_set(instance_var, value)
      end
    end

    # Apply array environment variable (comma-separated)
    def apply_env_array(env_var, instance_var)
      return unless ENV[env_var]

      value = ENV[env_var].split(',').map(&:strip).reject(&:empty?)
      instance_variable_set(instance_var, value) unless value.empty?
    end

    public

    # Environment-specific configuration presets
    def production_mode!
      @safe_mode = true
      @log_level = :warn
      @command_timeout = 15
      @max_results = 50
      @log_executions = true
    end

    def development_mode!
      @safe_mode = false
      @log_level = :debug
      @command_timeout = 60
      @max_results = 200
      @log_executions = false
    end

    def test_mode!
      @safe_mode = true
      @log_level = :error
      @command_timeout = 30
      @log_executions = false
    end
  end
end
