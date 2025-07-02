require 'timeout'
require 'stringio'
require 'concurrent-ruby'
require 'rails'

module RailsActiveMcp
  class ConsoleExecutor
    # Thread-safe execution errors
    class ExecutionError < StandardError; end
    class ThreadSafetyError < StandardError; end

    def initialize(config)
      @config = config
      @safety_checker = SafetyChecker.new(config)
      # Thread-safe mutex for critical sections
      @execution_mutex = Mutex.new
    end

    def execute(code, timeout: nil, safe_mode: nil, capture_output: true)
      timeout ||= @config.command_timeout
      safe_mode = @config.safe_mode if safe_mode.nil?

      # Pre-execution safety check
      if safe_mode
        safety_analysis = @safety_checker.analyze(code)
        raise RailsActiveMcp::SafetyError, "Code failed safety check: #{safety_analysis[:summary]}" unless safety_analysis[:safe]
      end

      # Log execution if enabled
      log_execution(code) if @config.log_executions

      # Execute with Rails 7.1 compatible thread safety
      result = execute_with_rails_executor(code, timeout, capture_output)

      # Post-execution processing
      process_result(result)
    rescue RailsActiveMcp::SafetyError => e
      {
        success: false,
        error: e.message,
        error_class: 'SafetyError',
        code: code
      }
    end

    def execute_safe_query(model:, method:, args: [], limit: nil)
      limit ||= @config.max_results

      begin
        # Validate model access
        raise RailsActiveMcp::SafetyError, "Access to model '#{model}' is not allowed" unless @config.model_allowed?(model)

        # Validate method safety
        raise RailsActiveMcp::SafetyError, "Method '#{method}' is not allowed for safe queries" unless safe_query_method?(method)

        # Execute with proper Rails executor and connection management
        execute_with_rails_executor_and_connection do
          model_class = model.to_s.constantize

          # Build and execute query
          query = if args.empty?
                    model_class.public_send(method)
                  else
                    model_class.public_send(method, *args)
                  end

          # Apply limit for enumerable results
          query = query.limit(limit) if query.respond_to?(:limit) && !count_method?(method)

          result = execute_query_with_timeout(query)

          {
            success: true,
            model: model,
            method: method,
            args: args,
            result: serialize_result(result),
            count: calculate_count(result),
            executed_at: Time.now
          }
        end
      rescue RailsActiveMcp::SafetyError => e
        {
          success: false,
          error: e.message,
          error_class: 'SafetyError',
          model: model,
          method: method,
          args: args
        }
      rescue StandardError => e
        log_error(e, { model: model, method: method, args: args })
        {
          success: false,
          error: e.message,
          error_class: e.class.name,
          model: model,
          method: method,
          args: args
        }
      end
    end

    def get_model_info(model_name)
      # Validate model access
      raise RailsActiveMcp::SafetyError, "Access to model '#{model_name}' is not allowed" unless @config.model_allowed?(model_name)

      begin
        model_class = model_name.to_s.constantize

        # Ensure it's an ActiveRecord model
        unless model_class.respond_to?(:columns) && model_class.respond_to?(:reflect_on_all_associations)
          raise RailsActiveMcp::SafetyError, "#{model_name} is not a valid ActiveRecord model"
        end

        # Extract model information
        columns_info = model_class.columns.map do |column|
          {
            name: column.name,
            type: column.type,
            primary: column.name == model_class.primary_key
          }
        end

        associations_info = model_class.reflect_on_all_associations.map do |association|
          {
            name: association.name,
            type: association.macro,
            class_name: association.class_name
          }
        end

        validators_info = if model_class.respond_to?(:validators)
                            model_class.validators.map do |validator|
                              {
                                type: validator.class.name,
                                attributes: validator.attributes,
                                options: validator.options
                              }
                            end
                          else
                            []
                          end

        {
          success: true,
          model_name: model_name,
          table_name: model_class.table_name,
          primary_key: model_class.primary_key,
          columns: columns_info,
          associations: associations_info,
          validators: validators_info,
          extracted_at: Time.now
        }
      rescue NameError => e
        {
          success: false,
          error: "Model '#{model_name}' not found: #{e.message}",
          error_class: 'NameError',
          model_name: model_name
        }
      rescue StandardError => e
        {
          success: false,
          error: e.message,
          error_class: e.class.name,
          model_name: model_name
        }
      end
    end

    def dry_run(code)
      # Analyze without executing
      safety_analysis = @safety_checker.analyze(code)

      {
        code: code,
        safety_analysis: safety_analysis,
        would_execute: safety_analysis[:safe] || !@config.safe_mode,
        estimated_risk: estimate_risk(safety_analysis),
        recommendations: generate_recommendations(safety_analysis)
      }
    end

    private

    def safe_query_method?(method)
      # Define safe read-only methods for database queries
      safe_methods = %w[
        find find_by find_by! first last
        where select limit offset order
        count size length exists? empty?
        pluck ids maximum minimum average sum
        group having joins includes
        readonly distinct unscope
        all none
      ]

      safe_methods.include?(method.to_s)
    end

    def execute_with_rails_executor(code, timeout, capture_output)
      if defined?(Rails) && Rails.application
        # Handle development mode reloading if needed
        handle_development_reloading if Rails.env.development?

        # Rails 7.1 compatible execution with proper dependency loading
        if defined?(ActiveSupport::Dependencies) && ActiveSupport::Dependencies.respond_to?(:interlock)
          ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
            Rails.application.executor.wrap do
              execute_with_connection_pool(code, timeout, capture_output)
            end
          end
        else
          # Fallback for older Rails versions
          Rails.application.executor.wrap do
            execute_with_connection_pool(code, timeout, capture_output)
          end
        end
      else
        # Non-Rails execution
        execute_with_timeout(code, timeout, capture_output)
      end
    rescue TimeoutError => e
      # Re-raise timeout errors as-is
      raise e
    rescue StandardError => e
      raise ThreadSafetyError, "Thread-safe execution failed: #{e.message}"
    end

    # Manage ActiveRecord connection pool properly
    def execute_with_connection_pool(code, timeout, capture_output)
      if defined?(::ActiveRecord::Base)
        ::ActiveRecord::Base.connection_pool.with_connection do
          execute_with_timeout(code, timeout, capture_output)
        end
      else
        execute_with_timeout(code, timeout, capture_output)
      end
    ensure
      # Clean up connections to prevent pool exhaustion
      if defined?(::ActiveRecord::Base)
        ::ActiveRecord::Base.clear_active_connections!
        # Probabilistic garbage collection for long-running processes
        GC.start if rand(100) < 5
      end
    end

    # Helper method for safe queries with proper Rails executor and connection management
    def execute_with_rails_executor_and_connection(&block)
      if defined?(Rails) && Rails.application
        if defined?(ActiveSupport::Dependencies) && ActiveSupport::Dependencies.respond_to?(:interlock)
          ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
            Rails.application.executor.wrap do
              if defined?(::ActiveRecord::Base)
                ::ActiveRecord::Base.connection_pool.with_connection(&block)
              else
                yield
              end
            end
          end
        else
          Rails.application.executor.wrap do
            if defined?(::ActiveRecord::Base)
              ::ActiveRecord::Base.connection_pool.with_connection(&block)
            else
              yield
            end
          end
        end
      else
        yield
      end
    ensure
      # Clean up connections
      if defined?(::ActiveRecord::Base)
        ::ActiveRecord::Base.clear_active_connections!
        # Probabilistic garbage collection for long-running processes
        GC.start if rand(100) < 5
      end
    end

    def execute_with_timeout(code, timeout, capture_output)
      Timeout.timeout(timeout) do
        if capture_output
          execute_with_captured_output(code)
        else
          execute_direct(code)
        end
      end
    rescue Timeout::Error
      raise TimeoutError, "Execution timed out after #{timeout} seconds"
    end

    def execute_with_captured_output(code)
      # Thread-safe output capture using mutex
      @execution_mutex.synchronize do
        # Capture both stdout and stderr to prevent any Rails output leakage
        old_stdout = $stdout
        old_stderr = $stderr
        captured_output = StringIO.new
        captured_errors = StringIO.new
        $stdout = captured_output
        $stderr = captured_errors

        begin
          # Create thread-safe execution context
          binding_context = create_thread_safe_console_binding

          # Execute code
          start_time = Time.now
          begin
            return_value = binding_context.eval(code)
          rescue SyntaxError => e
            return {
              success: false,
              error: "Syntax Error: #{e.message}",
              error_class: 'SyntaxError',
              backtrace: e.backtrace&.first(10),
              code: code,
              output: nil
            }
          end
          execution_time = Time.now - start_time

          output = captured_output.string
          errors = captured_errors.string

          # Combine output and errors for comprehensive result
          combined_output = [output, errors].reject(&:empty?).join("\n")

          {
            success: true,
            return_value: return_value,
            output: combined_output,
            return_value_string: safe_inspect(return_value),
            execution_time: execution_time,
            code: code
          }
        rescue StandardError => e
          execution_time = Time.now - start_time if defined?(start_time)
          errors = captured_errors.string

          {
            success: false,
            error: e.message,
            error_class: e.class.name,
            backtrace: e.backtrace&.first(10),
            execution_time: execution_time,
            code: code,
            stderr: errors.empty? ? nil : errors
          }
        ensure
          $stdout = old_stdout if old_stdout
          $stderr = old_stderr if old_stderr
        end
      end
    end

    def execute_direct(code)
      # Create thread-safe binding context
      binding_context = create_thread_safe_console_binding
      start_time = Time.now

      result = binding_context.eval(code)
      execution_time = Time.now - start_time

      {
        success: true,
        return_value: result,
        execution_time: execution_time,
        code: code
      }
    rescue StandardError => e
      execution_time = Time.now - start_time if defined?(start_time)

      {
        success: false,
        error: e.message,
        error_class: e.class.name,
        backtrace: e.backtrace&.first(10),
        execution_time: execution_time,
        code: code
      }
    end

    def execute_query_with_timeout(query)
      Timeout.timeout(@config.command_timeout) do
        if defined?(::ActiveRecord::Relation) && query.is_a?(::ActiveRecord::Relation)
          query.to_a
        else
          query
        end
      end
    end

    # Thread-safe console binding creation
    def create_thread_safe_console_binding
      # Create a new binding context for each execution to avoid shared state
      console_context = Object.new

      console_context.instance_eval do
        # Add Rails helpers if available (thread-safe)
        if defined?(Rails) && Rails.application
          # Only extend if routes are available and it's safe to do so
          extend Rails.application.routes.url_helpers if Rails.application.routes && !Rails.env.production?

          def reload!
            if defined?(Rails) && Rails.application && Rails.application.respond_to?(:reloader)
              Rails.application.reloader.reload!
              'Reloaded!'
            else
              'Reload not available'
            end
          end

          def app
            Rails.application if defined?(Rails)
          end

          def helper
            return unless defined?(ApplicationController) && ApplicationController.respond_to?(:helpers)

            ApplicationController.helpers
          end
        end

        # Add common console helpers (thread-safe)
        def sql(query)
          raise NoMethodError, 'ActiveRecord not available' unless defined?(::ActiveRecord::Base)

          ::ActiveRecord::Base.connection.select_all(query).to_a
        end

        def schema(table_name)
          raise NoMethodError, 'ActiveRecord not available' unless defined?(::ActiveRecord::Base)

          ::ActiveRecord::Base.connection.columns(table_name)
        end
      end

      console_context.instance_eval { binding }
    end

    # Previous methods remain the same but are now called within thread-safe context
    def create_console_binding
      # Delegate to thread-safe version
      create_thread_safe_console_binding
    end

    def safe_query_method?(method)
      safe_methods = %w[
        find find_by find_each find_in_batches
        where all first last take
        count sum average maximum minimum size length
        pluck ids exists? empty? any? many?
        select distinct group order limit offset
        includes joins left_joins preload eager_load
        to_a to_sql explain inspect as_json to_json
        attributes attribute_names column_names
        model_name table_name primary_key
      ]
      safe_methods.include?(method.to_s)
    end

    def count_method?(method)
      %w[count sum average maximum minimum size length].include?(method.to_s)
    end

    def serialize_result(result)
      case result
      when Array
        limited_result = result.first(@config.max_results)
        limited_result.map { |item| serialize_result(item) }
      when Hash
        result
      when Numeric, String, TrueClass, FalseClass, NilClass
        result
      else
        # Handle ActiveRecord objects if available
        if defined?(::ActiveRecord::Base) && result.is_a?(::ActiveRecord::Base)
          result.attributes.merge(_model_class: result.class.name)
        elsif defined?(::ActiveRecord::Relation) && result.is_a?(::ActiveRecord::Relation)
          serialize_result(result.to_a)
        else
          safe_inspect(result)
        end
      end
    end

    def calculate_count(result)
      case result
      when Array
        result.size
      when Numeric
        1
      else
        # Handle ActiveRecord::Relation if available
        if defined?(::ActiveRecord::Relation) && result.is_a?(::ActiveRecord::Relation)
          result.count
        else
          1
        end
      end
    end

    def safe_inspect(object)
      object.inspect
    rescue StandardError => e
      "#<#{object.class}:0x#{object.object_id.to_s(16)} (inspect failed: #{e.message})>"
    end

    def process_result(result)
      # Apply max results limit to output
      if result[:success] && result[:return_value].is_a?(Array) && (result[:return_value].size > @config.max_results)
        result[:return_value] = result[:return_value].first(@config.max_results)
        result[:truncated] = true
        result[:note] = "Result truncated to #{@config.max_results} items"
      end

      result
    end

    def estimate_risk(safety_analysis)
      return :low if safety_analysis[:safe]

      critical_count = safety_analysis[:violations].count { |v| v[:severity] == :critical }
      high_count = safety_analysis[:violations].count { |v| v[:severity] == :high }

      if critical_count > 0
        :critical
      elsif high_count > 0
        :high
      else
        :medium
      end
    end

    def generate_recommendations(safety_analysis)
      recommendations = []

      if safety_analysis[:violations].any?
        recommendations << 'Consider using read-only alternatives'
        recommendations << 'Review the code for unintended side effects'

        if safety_analysis[:violations].any? { |v| v[:severity] == :critical }
          recommendations << 'This code contains critical safety violations and should not be executed'
        end
      end

      recommendations << 'Consider using the safe_query tool for read-only operations' unless safety_analysis[:read_only]

      recommendations
    end

    def log_execution(code)
      return unless @config.audit_file

      log_entry = {
        timestamp: Time.now.iso8601,
        code: code,
        user: current_user_info,
        safety_check: @safety_checker.analyze(code)
      }

      File.open(@config.audit_file, 'a') do |f|
        f.puts(JSON.generate(log_entry))
      end
    rescue StandardError => e
      # Don't fail execution due to logging issues
      RailsActiveMcp.logger.warn "Failed to log Rails Active MCP execution: #{e.message}"
    end

    def log_error(error, context = {})
      return unless @config.audit_file

      log_entry = {
        timestamp: Time.now.iso8601,
        type: 'error',
        error: error.message,
        error_class: error.class.name,
        context: context,
        user: current_user_info
      }

      File.open(@config.audit_file, 'a') do |f|
        f.puts(JSON.generate(log_entry))
      end
    rescue StandardError
      # Silently fail logging
    end

    def current_user_info
      # Try to extract user info from various sources
      if defined?(Current) && Current.respond_to?(:user) && Current.user
        { id: Current.user.id, email: Current.user.email }
      elsif defined?(Rails) && Rails.env.development?
        { environment: 'development' }
      else
        { environment: Rails.env }
      end
    rescue StandardError
      { unknown: true }
    end

    # Handle development mode reloading safely
    def handle_development_reloading
      return unless Rails.env.development?
      return unless defined?(Rails.application.reloader)

      # Check if reloading is needed and safe to do
      Rails.application.reloader.reload! if Rails.application.reloader.check!
    rescue StandardError => e
      # Log but don't fail execution due to reloading issues
      RailsActiveMcp.logger.warn "Failed to reload in development: #{e.message}" if defined?(RailsActiveMcp.logger)
    end
  end
end
