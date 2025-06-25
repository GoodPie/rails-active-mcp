require 'timeout'
require 'stringio'
require 'concurrent-ruby'
require 'rails'

module RailsActiveMcp
  class ConsoleExecutor
    def initialize(config)
      @config = config
      @safety_checker = SafetyChecker.new(config)
    end

    def execute(code, timeout: nil, safe_mode: nil, capture_output: true)
      timeout ||= @config.default_timeout
      safe_mode = @config.safe_mode if safe_mode.nil?

      # Pre-execution safety check
      if safe_mode
        safety_analysis = @safety_checker.analyze(code)
        unless safety_analysis[:safe]
          raise SafetyError, "Code failed safety check: #{safety_analysis[:summary]}"
        end
      end

      # Log execution if enabled
      log_execution(code) if @config.log_executions

      # Execute with timeout and output capture
      result = execute_with_timeout(code, timeout, capture_output)

      # Post-execution processing
      process_result(result)
    end

    def execute_safe_query(model:, method:, args: [], limit: nil)
      limit ||= @config.max_results

      # Validate model access
      unless @config.model_allowed?(model)
        raise SafetyError, "Access to model '#{model}' is not allowed"
      end

      # Validate method safety
      unless safe_query_method?(method)
        raise SafetyError, "Method '#{method}' is not allowed for safe queries"
      end

      begin
        model_class = model.to_s.constantize

        # Build and execute query
        query = if args.empty?
                  model_class.public_send(method)
                else
                  model_class.public_send(method, *args)
                end

        # Apply limit for enumerable results
        if query.respond_to?(:limit) && !count_method?(method)
          query = query.limit(limit)
        end

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
      rescue => e
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
      # Capture both stdout and the return value
      old_stdout = $stdout
      captured_output = StringIO.new
      $stdout = captured_output

      # Create execution context
      binding_context = create_console_binding

      # Execute code
      start_time = Time.now
      return_value = binding_context.eval(code)
      execution_time = Time.now - start_time

      output = captured_output.string
      $stdout = old_stdout

      {
        success: true,
        return_value: return_value,
        output: output,
        return_value_string: safe_inspect(return_value),
        execution_time: execution_time,
        code: code
      }
    rescue => e
      $stdout = old_stdout if old_stdout
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

    def execute_direct(code)
      binding_context = create_console_binding
      start_time = Time.now

      result = binding_context.eval(code)
      execution_time = Time.now - start_time

      {
        success: true,
        return_value: result,
        execution_time: execution_time,
        code: code
      }
    rescue => e
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
      Timeout.timeout(@config.default_timeout) do
        if query.is_a?(ActiveRecord::Relation)
          query.to_a
        else
          query
        end
      end
    end

    def create_console_binding
      # Create a clean binding with Rails console helpers
      console_context = Object.new

      console_context.instance_eval do
        # Add Rails helpers if available
        if defined?(Rails)
          extend Rails.application.routes.url_helpers

          def reload!
            Rails.application.reloader.reload!
            "Reloaded!"
          end

          def app
            Rails.application
          end

          def helper
            ApplicationController.helpers
          end
        end

        # Add common console helpers
        def sql(query)
          ActiveRecord::Base.connection.select_all(query).to_a
        end

        def schema(table_name)
          ActiveRecord::Base.connection.columns(table_name)
        end
      end

      console_context.instance_eval { binding }
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
      when ActiveRecord::Base
        result.attributes.merge(_model_class: result.class.name)
      when Array
        limited_result = result.first(@config.max_results)
        limited_result.map { |item| serialize_result(item) }
      when ActiveRecord::Relation
        serialize_result(result.to_a)
      when Hash
        result
      when Numeric, String, TrueClass, FalseClass, NilClass
        result
      else
        safe_inspect(result)
      end
    end

    def calculate_count(result)
      case result
      when Array
        result.size
      when ActiveRecord::Relation
        result.count
      when Numeric
        1
      else
        1
      end
    end

    def safe_inspect(object)
      object.inspect
    rescue => e
      "#<#{object.class}:0x#{object.object_id.to_s(16)} (inspect failed: #{e.message})>"
    end

    def process_result(result)
      # Apply max results limit to output
      if result[:success] && result[:return_value].is_a?(Array)
        if result[:return_value].size > @config.max_results
          result[:return_value] = result[:return_value].first(@config.max_results)
          result[:truncated] = true
          result[:note] = "Result truncated to #{@config.max_results} items"
        end
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
        recommendations << "Consider using read-only alternatives"
        recommendations << "Review the code for unintended side effects"

        if safety_analysis[:violations].any? { |v| v[:severity] == :critical }
          recommendations << "This code contains critical safety violations and should not be executed"
        end
      end

      unless safety_analysis[:read_only]
        recommendations << "Consider using the safe_query tool for read-only operations"
      end

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
    rescue => e
      # Don't fail execution due to logging issues
      Rails.logger.warn "Failed to log Rails Active MCP execution: #{e.message}" if defined?(Rails)
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
    rescue
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
    rescue
      { unknown: true }
    end
  end
end