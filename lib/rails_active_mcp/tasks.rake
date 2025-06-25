namespace :rails_active_mcp do
  desc "Check the safety of Ruby code"
  task :check_safety, [:code] => :environment do |task, args|
    code = args[:code]

    if code.blank?
      puts "Usage: rails rails_active_mcp:check_safety['User.count']"
      exit 1
    end

    safety_checker = RailsActiveMcp::SafetyChecker.new(RailsActiveMcp.config)
    analysis = safety_checker.analyze(code)

    puts "Code: #{code}"
    puts "Safe: #{analysis[:safe] ? 'Yes' : 'No'}"
    puts "Read-only: #{analysis[:read_only] ? 'Yes' : 'No'}"
    puts "Summary: #{analysis[:summary]}"

    if analysis[:violations].any?
      puts "\nViolations:"
      analysis[:violations].each do |violation|
        puts "  - #{violation[:description]} (#{violation[:severity]})"
      end
    end
  end

  desc "Execute Ruby code with safety checks"
  task :execute, [:code] => :environment do |task, args|
    code = args[:code]

    if code.blank?
      puts "Usage: rails rails_active_mcp:execute['User.count']"
      exit 1
    end

    begin
      result = RailsActiveMcp.execute(code)

      if result[:success]
        puts "Result: #{result[:return_value_string] || result[:return_value]}"
        puts "Output: #{result[:output]}" if result[:output].present?
        puts "Execution time: #{result[:execution_time]}s" if result[:execution_time]
      else
        puts "Error: #{result[:error]}"
        puts "Error class: #{result[:error_class]}" if result[:error_class]
      end
    rescue => e
      puts "Failed to execute: #{e.message}"
      exit 1
    end
  end

  desc "Test MCP tools"
  task :test_tools => :environment do
    puts "Testing Rails Active MCP tools..."

    # Test SafeQueryTool
    puts "\n1. Testing SafeQueryTool..."
    if defined?(User)
      tool = RailsActiveMcp::Tools::SafeQueryTool.new
      result = tool.call(model: "User", method: "count")
      puts "  User.count: #{result[:success] ? result[:result] : result[:error]}"
    else
      puts "  Skipped (User model not found)"
    end

    # Test ConsoleExecuteTool
    puts "\n2. Testing ConsoleExecuteTool..."
    tool = RailsActiveMcp::Tools::ConsoleExecuteTool.new
    result = tool.call(code: "1 + 1")
    puts "  1 + 1: #{result[:success] ? result[:return_value] : result[:error]}"

    # Test DryRunTool
    puts "\n3. Testing DryRunTool..."
    tool = RailsActiveMcp::Tools::DryRunTool.new
    result = tool.call(code: "User.delete_all")
    puts "  User.delete_all analysis: #{result[:estimated_risk]} risk"

    puts "\nAll tools tested!"
  end

  desc "Show configuration"
  task :config => :environment do
    config = RailsActiveMcp.config

    puts "Rails Active MCP Configuration:"
    puts "  Enabled: #{config.enabled}"
    puts "  Safe mode: #{config.safe_mode}"
    puts "  Default timeout: #{config.default_timeout}s"
    puts "  Max results: #{config.max_results}"
    puts "  Log executions: #{config.log_executions}"
    puts "  Audit file: #{config.audit_file}"
    puts "  Enable mutation tools: #{config.enable_mutation_tools}"
    puts "  Execution environment: #{config.execution_environment}"

    if config.allowed_models.any?
      puts "  Allowed models: #{config.allowed_models.join(', ')}"
    end

    if config.blocked_models.any?
      puts "  Blocked models: #{config.blocked_models.join(', ')}"
    end

    if config.custom_safety_patterns.any?
      puts "  Custom safety patterns: #{config.custom_safety_patterns.size}"
    end
  end

  desc "View audit log"
  task :audit_log, [:lines] => :environment do |task, args|
    lines = args[:lines]&.to_i || 10
    audit_file = RailsActiveMcp.config.audit_file

    unless File.exist?(audit_file)
      puts "Audit log not found at: #{audit_file}"
      exit 1
    end

    puts "Last #{lines} entries from audit log:"
    puts "=" * 50

    File.readlines(audit_file).last(lines).each do |line|
      begin
        entry = JSON.parse(line)
        timestamp = entry['timestamp']
        code = entry['code']
        user = entry.dig('user', 'email') || entry.dig('user', 'environment') || 'unknown'

        puts "#{timestamp} [#{user}]: #{code}"

        if entry['type'] == 'error'
          puts "  ERROR: #{entry['error']}"
        elsif entry['safety_check'] && !entry['safety_check']['safe']
          puts "  SAFETY: #{entry['safety_check']['summary']}"
        end
        puts
      rescue JSON::ParserError
        puts "Invalid JSON entry: #{line}"
      end
    end
  end

  desc "Clear audit log"
  task :clear_audit_log => :environment do
    audit_file = RailsActiveMcp.config.audit_file

    if File.exist?(audit_file)
      File.truncate(audit_file, 0)
      puts "Audit log cleared: #{audit_file}"
    else
      puts "Audit log not found: #{audit_file}"
    end
  end
end