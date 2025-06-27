# frozen_string_literal: true

require 'fileutils'

module RailsActiveMcp
  class Configuration
    # Core configuration options
    attr_accessor :allowed_commands, :command_timeout, :enable_logging, :log_level

    # Safety and execution options
    attr_accessor :safe_mode, :default_timeout, :max_results, :log_executions, :audit_file
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
      @default_timeout = 30
      @max_results = 100
      @log_executions = false
      @audit_file = nil
      @custom_safety_patterns = []
      @allowed_models = []
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
        default_timeout.is_a?(Numeric) && default_timeout > 0 &&
        max_results.is_a?(Numeric) && max_results > 0 &&
        [true, false].include?(log_executions) &&
        custom_safety_patterns.is_a?(Array) &&
        allowed_models.is_a?(Array)
    end

    def reset!
      initialize
    end
  end
end
