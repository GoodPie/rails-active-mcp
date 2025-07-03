# frozen_string_literal: true

require 'fileutils'

module RailsActiveMcp
  class Configuration
    # Core configuration options
    attr_accessor :allowed_commands, :command_timeout, :enable_logging, :log_level

    # Safety and execution options
    attr_accessor :safe_mode, :max_results, :log_executions, :audit_file, :enabled
    attr_accessor :custom_safety_patterns, :allowed_models

    def initialize
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
