require 'fileutils'

module RailsActiveMcp
  class Configuration
    attr_accessor :enabled, :safe_mode, :default_timeout, :max_results,
                  :allowed_models, :blocked_models, :custom_safety_patterns,
                  :log_executions, :audit_file, :enable_mutation_tools,
                  :require_confirmation_for, :execution_environment

    def initialize
      @enabled = true
      @safe_mode = true
      @default_timeout = 30
      @max_results = 100
      @allowed_models = [] # Empty means all models allowed
      @blocked_models = []
      @custom_safety_patterns = []
      @log_executions = true
      # Safe Rails.root access
      @audit_file = rails_root_join("log", "rails_active_mcp.log") if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
      @enable_mutation_tools = false
      @require_confirmation_for = [:delete, :destroy, :update_all, :delete_all]
      @execution_environment = :current # :current, :sandbox, :readonly_replica
    end

    # Safety configuration
    def strict_mode!
      @safe_mode = true
      @enable_mutation_tools = false
      @default_timeout = 15
      @max_results = 50
    end

    def permissive_mode!
      @safe_mode = false
      @enable_mutation_tools = true
      @default_timeout = 60
      @max_results = 1000
    end

    def production_mode!
      strict_mode!
      @execution_environment = :readonly_replica
      @log_executions = true
      @require_confirmation_for = [:delete, :destroy, :update, :create, :save]
    end

    # Model access configuration
    def allow_models(*models)
      @allowed_models.concat(models.map(&:to_s))
    end

    def block_models(*models)
      @blocked_models.concat(models.map(&:to_s))
    end

    def add_safety_pattern(pattern, description = nil)
      @custom_safety_patterns << { pattern: pattern, description: description }
    end

    # Validation
    def model_allowed?(model_name)
      model_str = model_name.to_s

      # Check if specifically blocked
      return false if @blocked_models.include?(model_str)

      # If allow list is empty, allow all (except blocked)
      return true if @allowed_models.empty?

      # Check allow list
      @allowed_models.include?(model_str)
    end

    def validate!
      raise ArgumentError, "timeout must be positive" if @default_timeout <= 0
      raise ArgumentError, "max_results must be positive" if @max_results <= 0

      if defined?(Rails) && @audit_file
        audit_dir = File.dirname(@audit_file)
        FileUtils.mkdir_p(audit_dir) unless File.directory?(audit_dir)
      end
    end

    private

    def rails_root_join(*args)
      if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
        Rails.root.join(*args)
      else
        File.join(Dir.pwd, *args)
      end
    end
  end
end
