# frozen_string_literal: true

require 'json'
require 'logger'

module RailsActiveMcp
  class StdioServer
    JSONRPC_VERSION = '2.0'
    MCP_VERSION = '2025-06-18'

    def initialize
      @tools = {}
      @logger = Logger.new(STDERR) # Log to stderr to avoid interfering with stdout
      @logger.level = ENV['RAILS_MCP_DEBUG'] ? Logger::DEBUG : Logger::ERROR
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime}] [RAILS-MCP] #{severity}: #{msg}\n"
      end
      register_default_tools
      @logger.info "Rails Active MCP Server initialized with #{@tools.size} tools"
    end

    def run
      @logger.info 'Starting Rails Active MCP Stdio Server'
      send_log_notification('info', 'Rails Active MCP Server started successfully')

      STDIN.each_line do |line|
        line = line.strip
        next if line.empty?

        @logger.debug "Received request: #{line}" if ENV['RAILS_MCP_DEBUG']
        data = JSON.parse(line)

        @logger.debug "Processing method: #{data['method']}" if ENV['RAILS_MCP_DEBUG']
        response = handle_jsonrpc_request(data)

        if response
          @logger.debug "Sending response: #{response.to_json}" if ENV['RAILS_MCP_DEBUG']
          puts response.to_json
          STDOUT.flush
        end
      rescue JSON::ParserError => e
        @logger.error "JSON Parse Error: #{e.message}"
        send_log_notification('error', "JSON Parse Error: #{e.message}")
        error_response = jsonrpc_error(nil, -32_700, 'Parse error')
        puts error_response.to_json
        STDOUT.flush
      rescue StandardError => e
        @logger.error "Unexpected error: #{e.message}"
        @logger.error e.backtrace.join("\n")
        send_log_notification('error', "Server error: #{e.message}")
        error_response = jsonrpc_error(nil, -32_603, 'Internal error')
        puts error_response.to_json
        STDOUT.flush
      end
    end

    private

    def handle_jsonrpc_request(data)
      case data['method']
      when 'initialize'
        handle_initialize(data)
      when 'tools/list'
        handle_tools_list(data)
      when 'tools/call'
        handle_tools_call(data)
      when 'resources/list'
        handle_resources_list(data)
      when 'resources/read'
        handle_resources_read(data)
      when 'ping'
        handle_ping(data)
      else
        jsonrpc_error(data['id'], -32_601, 'Method not found')
      end
    end

    def handle_initialize(data)
      {
        jsonrpc: JSONRPC_VERSION,
        id: data['id'],
        result: {
          protocolVersion: MCP_VERSION,
          capabilities: {
            tools: {},
            resources: {}
          },
          serverInfo: {
            name: 'rails-active-mcp',
            version: RailsActiveMcp::VERSION
          }
        }
      }
    end

    def handle_tools_list(data)
      tools_array = @tools.values.map do |tool|
        tool_def = {
          name: tool[:name],
          description: tool[:description],
          inputSchema: tool[:input_schema]
        }

        # Add annotations if present
        tool_def[:annotations] = tool[:annotations] if tool[:annotations] && !tool[:annotations].empty?

        tool_def
      end

      {
        jsonrpc: JSONRPC_VERSION,
        id: data['id'],
        result: { tools: tools_array }
      }
    end

    def handle_tools_call(data)
      tool_name = data.dig('params', 'name')
      arguments = data.dig('params', 'arguments') || {}

      tool = @tools[tool_name]
      return jsonrpc_error(data['id'], -32_602, "Tool '#{tool_name}' not found") unless tool

      @logger.info "Executing tool: #{tool_name}"
      send_log_notification('info', "Executing tool: #{tool_name}")

      begin
        start_time = Time.now
        result = tool[:handler].call(arguments)
        execution_time = Time.now - start_time

        @logger.info "Tool #{tool_name} completed in #{execution_time}s"
        send_log_notification('info', "Tool #{tool_name} completed successfully")

        {
          jsonrpc: JSONRPC_VERSION,
          id: data['id'],
          result: {
            content: [{ type: 'text', text: result.to_s }],
            isError: false
          }
        }
      rescue StandardError => e
        @logger.error "Tool execution error: #{e.message}"
        @logger.error e.backtrace.first(5).join("\n") if ENV['RAILS_MCP_DEBUG']
        send_log_notification('error', "Tool #{tool_name} failed: #{e.message}")

        {
          jsonrpc: JSONRPC_VERSION,
          id: data['id'],
          result: {
            content: [{ type: 'text', text: "Error: #{e.message}" }],
            isError: true
          }
        }
      end
    end

    def handle_resources_list(data)
      {
        jsonrpc: JSONRPC_VERSION,
        id: data['id'],
        result: { resources: [] }
      }
    end

    def handle_resources_read(data)
      {
        jsonrpc: JSONRPC_VERSION,
        id: data['id'],
        result: { contents: [] }
      }
    end

    def handle_ping(data)
      {
        jsonrpc: JSONRPC_VERSION,
        id: data['id'],
        result: {}
      }
    end

    def register_tool(name, description, input_schema, annotations = {}, &handler)
      @tools[name] = {
        name: name,
        description: description,
        input_schema: input_schema,
        annotations: annotations,
        handler: handler
      }
    end

    def register_default_tools
      register_tool(
        'rails_console_execute',
        'Execute Ruby code in Rails console context',
        {
          type: 'object',
          properties: {
            code: { type: 'string', description: 'Ruby code to execute' },
            timeout: { type: 'number', description: 'Timeout in seconds', default: 30 },
            safe_mode: { type: 'boolean', description: 'Enable safety checks', default: true },
            capture_output: { type: 'boolean', description: 'Capture console output', default: true }
          },
          required: ['code']
        },
        {
          title: 'Rails Console Executor',
          readOnlyHint: false,
          destructiveHint: true,
          idempotentHint: false,
          openWorldHint: false
        }
      ) do |args|
        execute_console_code(args)
      end

      register_tool(
        'rails_model_info',
        'Get information about Rails models including columns, associations, and table structure',
        {
          type: 'object',
          properties: {
            model_name: { type: 'string', description: 'Name of the Rails model class to inspect' }
          },
          required: ['model_name']
        },
        {
          title: 'Rails Model Inspector',
          readOnlyHint: true,
          destructiveHint: false,
          idempotentHint: true,
          openWorldHint: false
        }
      ) do |args|
        get_model_info(args['model_name'])
      end

      register_tool(
        'rails_safe_query',
        'Execute safe read-only database queries using ActiveRecord',
        {
          type: 'object',
          properties: {
            query: { type: 'string', description: 'ActiveRecord query to execute (read-only methods only)' },
            model: { type: 'string', description: 'Model class name to query against' }
          },
          required: %w[query model]
        },
        {
          title: 'Rails Safe Query Executor',
          readOnlyHint: true,
          destructiveHint: false,
          idempotentHint: true,
          openWorldHint: false
        }
      ) do |args|
        execute_safe_query(args)
      end

      register_tool(
        'rails_dry_run',
        'Analyze Ruby code for safety without executing it',
        {
          type: 'object',
          properties: {
            code: { type: 'string', description: 'Ruby code to analyze for safety and potential issues' }
          },
          required: ['code']
        },
        {
          title: 'Rails Code Safety Analyzer',
          readOnlyHint: true,
          destructiveHint: false,
          idempotentHint: true,
          openWorldHint: false
        }
      ) do |args|
        dry_run_analysis(args['code'])
      end
    end

    # Tool implementation methods (reused from McpServer)
    def execute_console_code(args)
      unless defined?(RailsActiveMcp) && RailsActiveMcp.respond_to?(:config) && RailsActiveMcp.config.enabled
        return 'Rails Active MCP is disabled. Enable it in your Rails configuration.'
      end

      executor = RailsActiveMcp::ConsoleExecutor.new(RailsActiveMcp.config)

      begin
        result = executor.execute(
          args['code'],
          timeout: args['timeout'] || 30,
          safe_mode: args['safe_mode'] != false,
          capture_output: args['capture_output'] != false
        )

        if result[:success]
          format_success_result(result)
        else
          "Error: #{result[:error]} (#{result[:error_class]})"
        end
      rescue RailsActiveMcp::SafetyError => e
        "Safety check failed: #{e.message}"
      rescue RailsActiveMcp::TimeoutError => e
        "Execution timed out: #{e.message}"
      rescue StandardError => e
        "Execution failed: #{e.message}"
      end
    end

    def get_model_info(model_name)
      unless defined?(RailsActiveMcp) && RailsActiveMcp.respond_to?(:config) && RailsActiveMcp.config.enabled
        return 'Rails Active MCP is disabled. Enable it in your Rails configuration.'
      end

      begin
        # Try to load Rails environment if not already loaded
        require_relative '../../../config/environment' if !defined?(Rails) && File.exist?('config/environment.rb')

        model_class = model_name.constantize
        unless defined?(ActiveRecord) && model_class < ActiveRecord::Base
          return "#{model_name} is not an ActiveRecord model"
        end

        info = []
        info << "Model: #{model_class.name}"
        info << "Table: #{model_class.table_name}"
        info << "Columns: #{model_class.column_names.join(', ')}"

        associations = model_class.reflect_on_all_associations.map(&:name)
        info << "Associations: #{associations.any? ? associations.join(', ') : 'None'}"

        # Add validation info if available
        if model_class.respond_to?(:validators) && model_class.validators.any?
          validations = model_class.validators.map { |v| "#{v.attributes.join(', ')}: #{v.class.name.demodulize}" }.uniq
          info << "Validations: #{validations.join(', ')}"
        end

        info.join("\n")
      rescue NameError
        "Model '#{model_name}' not found. Make sure the model class exists and is properly defined."
      rescue StandardError => e
        "Error getting model info: #{e.message}"
      end
    end

    def execute_safe_query(args)
      unless defined?(RailsActiveMcp) && RailsActiveMcp.respond_to?(:config) && RailsActiveMcp.config.enabled
        return 'Rails Active MCP is disabled. Enable it in your Rails configuration.'
      end

      begin
        # Try to load Rails environment if not already loaded
        require_relative '../../../config/environment' if !defined?(Rails) && File.exist?('config/environment.rb')

        model_class = args['model'].constantize
        unless defined?(ActiveRecord) && model_class < ActiveRecord::Base
          return "#{args['model']} is not an ActiveRecord model"
        end

        # Only allow safe read-only methods
        safe_methods = %w[find find_by where select count sum average maximum minimum first last pluck ids exists?
                          empty? any? many? include? limit offset order group having joins includes references distinct uniq readonly]

        # Extract the first method call to validate it's safe
        query_parts = args['query'].split('.')
        query_method = query_parts.first.split('(').first

        unless safe_methods.include?(query_method)
          return "Unsafe query method: #{query_method}. Only read-only methods are allowed."
        end

        result = model_class.instance_eval(args['query'])

        # Format result appropriately
        case result
        when ActiveRecord::Relation
          "Query returned #{result.count} records: #{result.limit(10).pluck(:id).join(', ')}#{result.count > 10 ? '...' : ''}"
        when Array
          "Array with #{result.length} items: #{result.take(5).inspect}#{result.length > 5 ? '...' : ''}"
        else
          result.to_s
        end
      rescue NameError
        "Model '#{args['model']}' not found. Make sure the model class exists and is properly defined."
      rescue StandardError => e
        "Error executing query: #{e.message}"
      end
    end

    def dry_run_analysis(code)
      unless defined?(RailsActiveMcp) && RailsActiveMcp.respond_to?(:config) && RailsActiveMcp.config.enabled
        return 'Rails Active MCP is disabled. Enable it in your Rails configuration.'
      end

      executor = RailsActiveMcp::ConsoleExecutor.new(RailsActiveMcp.config)

      begin
        analysis = executor.dry_run(code)

        output = []
        output << 'Code Analysis Results:'
        output << "Code: #{analysis[:code]}"
        output << "Safe: #{analysis[:safety_analysis][:safe] ? 'Yes' : 'No'}"
        output << "Read-only: #{analysis[:safety_analysis][:read_only] ? 'Yes' : 'No'}"
        output << "Risk level: #{analysis[:estimated_risk]}"
        output << "Would execute: #{analysis[:would_execute] ? 'Yes' : 'No'}"
        output << "Summary: #{analysis[:safety_analysis][:summary]}"

        if analysis[:safety_analysis][:violations] && analysis[:safety_analysis][:violations].any?
          output << "\nSafety Violations:"
          analysis[:safety_analysis][:violations].each do |violation|
            output << "  - #{violation[:description]} (#{violation[:severity]})"
          end
        end

        if analysis[:recommendations] && analysis[:recommendations].any?
          output << "\nRecommendations:"
          analysis[:recommendations].each do |rec|
            output << "  - #{rec}"
          end
        end

        output.join("\n")
      rescue StandardError => e
        "Analysis failed: #{e.message}. Make sure the Rails environment is properly loaded."
      end
    end

    def format_success_result(result)
      output = []
      output << 'Execution Results:'
      output << "Code: #{result[:code]}"
      output << "Result: #{result[:return_value_string] || result[:return_value]}"
      output << "Output: #{result[:output]}" if result[:output] && !result[:output].empty?
      output << "Execution time: #{result[:execution_time]}s" if result[:execution_time]
      output << "Note: #{result[:note]}" if result[:note]
      output.join("\n")
    end

    def send_log_notification(level, message)
      notification = {
        jsonrpc: JSONRPC_VERSION,
        method: 'notifications/message',
        params: {
          level: level,
          data: message
        }
      }

      puts notification.to_json
      STDOUT.flush
    rescue StandardError => e
      @logger.error "Failed to send log notification: #{e.message}"
    end

    def jsonrpc_error(id, code, message)
      {
        jsonrpc: JSONRPC_VERSION,
        id: id,
        error: { code: code, message: message }
      }
    end
  end
end
