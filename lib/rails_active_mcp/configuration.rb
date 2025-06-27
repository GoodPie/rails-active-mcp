# frozen_string_literal: true

require 'fileutils'

module RailsActiveMcp
  class Configuration
    # Core configuration options
    attr_accessor :allowed_commands, :command_timeout, :enable_logging, :log_level

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
    end

    def valid?
      allowed_commands.is_a?(Array) &&
        command_timeout.is_a?(Numeric) && command_timeout > 0 &&
        [true, false].include?(enable_logging) &&
        %i[debug info warn error].include?(log_level)
    end

    def reset!
      initialize
    end
  end
end
