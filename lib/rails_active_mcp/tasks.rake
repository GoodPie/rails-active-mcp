namespace :rails_active_mcp do
  desc 'Check the safety of Ruby code'
  task :check_safety, [:code] => :environment do |_task, args|
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

  desc 'Execute Ruby code with safety checks'
  task :execute, [:code] => :environment do |_task, args|
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
    rescue StandardError => e
      puts "Failed to execute: #{e.message}"
      exit 1
    end
  end

  desc 'Test MCP tools'
  task test_tools: :environment do
    puts 'Testing Rails Active MCP tools...'

    # Test console execution
    puts "\n1. Testing console_execute tool:"
    result = RailsActiveMcp.execute('1 + 1')
    puts "  Simple math: #{result[:success] ? 'PASS' : 'FAIL'}"

    # Test safety checking
    puts "\n2. Testing safety checking:"
    safe_result = RailsActiveMcp.safe?('User.count')
    dangerous_result = RailsActiveMcp.safe?('User.delete_all')
    puts "  Safe code detection: #{safe_result ? 'PASS' : 'FAIL'}"
    puts "  Dangerous code detection: #{dangerous_result ? 'FAIL' : 'PASS'}"

    # Test Rails integration
    puts "\n3. Testing Rails integration:"
    if defined?(Rails) && Rails.respond_to?(:env)
      puts "  Rails environment: #{Rails.env} - PASS"
    else
      puts '  Rails environment: NOT DETECTED - FAIL'
    end

    puts "\nAll tests completed!"
  end

  desc 'Benchmark MCP tools performance'
  task benchmark: :environment do
    require 'benchmark'

    puts 'Rails Active MCP Performance Benchmark'
    puts '=' * 50

    # Benchmark safety checking
    puts "\nSafety Checker Performance:"
    Benchmark.bm(20) do |x|
      x.report('Simple check:') do
        1000.times { RailsActiveMcp.safe?('User.count') }
      end

      x.report('Complex check:') do
        100.times { RailsActiveMcp.safe?('User.where(active: true).includes(:posts).limit(10)') }
      end

      x.report('Dangerous check:') do
        1000.times { RailsActiveMcp.safe?('User.delete_all') }
      end
    end

    # Benchmark code execution
    puts "\nCode Execution Performance:"
    Benchmark.bm(20) do |x|
      x.report('Simple math:') do
        100.times { RailsActiveMcp.execute('1 + 1') }
      end

      x.report('String operations:') do
        100.times { RailsActiveMcp.execute('"hello".upcase') }
      end
    end
  end

  desc 'Validate Rails Active MCP configuration'
  task validate_config: :environment do
    puts 'Validating Rails Active MCP configuration...'

    config = RailsActiveMcp.config

    if config.valid?
      puts '✅ Configuration is valid'

      puts "\nCurrent Settings:"
      puts "  Safe mode: #{config.safe_mode}"
      puts "  Command timeout: #{config.command_timeout}s"
      puts "  Max results: #{config.max_results}"
      puts "  Log executions: #{config.log_executions}"
      puts "  Log level: #{config.log_level}"
      puts "  Allowed models: #{config.allowed_models.any? ? config.allowed_models.join(', ') : 'All models allowed'}"
      puts "  Custom safety patterns: #{config.custom_safety_patterns.length} patterns"
    else
      puts '❌ Configuration is invalid'
      puts 'Please check your config/initializers/rails_active_mcp.rb file'
      exit 1
    end
  end

  desc 'Generate example usage documentation'
  task generate_examples: :environment do
    examples_file = Rails.root.join('doc/rails_active_mcp_examples.md')
    FileUtils.mkdir_p(File.dirname(examples_file))

    content = <<~MARKDOWN
      # Rails Active MCP Usage Examples

      Generated on #{Date.current}

      ## Safe Operations

      These operations are considered safe and can be executed in safe mode:

      ```ruby
      # Basic model queries
      User.count
      User.all.limit(10)
      User.where(active: true)
      User.find(1)

      # Associations
      User.includes(:posts).limit(5)
      Post.joins(:user).where(users: { active: true })

      # Aggregations
      Order.sum(:total_amount)
      User.group(:status).count

      # System information
      Rails.env
      Rails.version
      Time.current
      ```

      ## Dangerous Operations (Blocked in Safe Mode)

      These operations are blocked when safe_mode is enabled:

      ```ruby
      # Mass deletions
      User.delete_all
      User.destroy_all

      # System commands
      system('rm -rf /')
      `ls -la`

      # File operations
      File.delete('important_file.txt')
      FileUtils.rm_rf('/important/directory')

      # Code evaluation
      eval(user_input)
      send(dynamic_method)
      ```

      ## Claude Desktop Usage Examples

      Ask Claude these questions to interact with your Rails app:

      - "How many users do we have?"
      - "Show me the User model structure"
      - "What are the most recent orders?"
      - "Check if this code is safe: User.where(active: false).delete_all"
      - "Find users created in the last week"
      - "What associations does the Post model have?"

      ## Configuration Examples

      ### Development Configuration
      ```ruby
      RailsActiveMcp.configure do |config|
        config.safe_mode = false
        config.log_level = :debug
        config.command_timeout = 60
        config.max_results = 200
      end
      ```

      ### Production Configuration
      ```ruby
      RailsActiveMcp.configure do |config|
        config.safe_mode = true
        config.log_level = :warn
        config.command_timeout = 15
        config.max_results = 50
        config.allowed_models = %w[User Post Comment]
      end
      ```
    MARKDOWN

    File.write(examples_file, content)
    puts "Examples generated at: #{examples_file}"
  end

  desc 'Install Claude Desktop configuration'
  task install_claude_config: :environment do
    config_template = {
      mcpServers: {
        'rails-active-mcp' => {
          command: Rails.root.join('bin/rails-active-mcp-wrapper').to_s,
          cwd: Rails.root.to_s,
          env: {
            RAILS_ENV: Rails.env
          }
        }
      }
    }

    puts 'Claude Desktop Configuration:'
    puts JSON.pretty_generate(config_template)
    puts ''
    puts 'Add this to your Claude Desktop configuration file:'
    puts '  macOS/Linux: ~/.config/claude-desktop/claude_desktop_config.json'
    puts '  Windows: %APPDATA%\\Claude\\claude_desktop_config.json'
  end

  desc 'Show comprehensive status and diagnostics'
  task status: :environment do
    puts 'Rails Active MCP Status Report'
    puts '=' * 50

    # Basic environment info
    puts "\n📋 Environment Information:"
    puts "  Rails version: #{Rails.version}"
    puts "  Ruby version: #{RUBY_VERSION}"
    puts "  Rails environment: #{Rails.env}"
    puts "  Rails Active MCP version: #{RailsActiveMcp::VERSION}"

    # Configuration status
    puts "\n⚙️  Configuration Status:"
    config = RailsActiveMcp.config
    puts "  Valid: #{config.valid? ? '✅' : '❌'}"
    puts "  Safe mode: #{config.safe_mode ? '🔒 Enabled' : '⚠️  Disabled'}"
    puts "  Timeout: #{config.command_timeout}s"
    puts "  Max results: #{config.max_results}"

    # File status
    puts "\n📁 File Status:"
    files_to_check = [
      'bin/rails-active-mcp-server',
      'bin/rails-active-mcp-wrapper',
      'config/initializers/rails_active_mcp.rb'
    ]

    files_to_check.each do |file|
      full_path = Rails.root.join(file)
      if File.exist?(full_path)
        executable = File.executable?(full_path)
        puts "  #{file}: ✅ #{'(executable)' if executable}"
      else
        puts "  #{file}: ❌ Missing"
      end
    end

    # Test basic functionality
    puts "\n🧪 Functionality Test:"
    begin
      test_result = RailsActiveMcp.execute('1 + 1')
      puts "  Basic execution: #{test_result[:success] ? '✅' : '❌'}"
    rescue StandardError => e
      puts "  Basic execution: ❌ (#{e.message})"
    end

    puts "\n🔗 Integration URLs:"
    puts '  Documentation: https://github.com/goodpie/rails-active-mcp'
    puts '  Issues: https://github.com/goodpie/rails-active-mcp/issues'
    puts '  MCP Protocol: https://modelcontextprotocol.io'
  end
end
