# frozen_string_literal: true

# noinspection RubyResolve
require 'spec_helper'

RSpec.describe RailsActiveMcp::ConsoleExecutor do
  let(:config) { RailsActiveMcp::Configuration.new }
  let(:executor) { described_class.new(config) }

  before do
    # Set up basic configuration for testing
    config.safe_mode = false # Disable for basic tests to allow simple Ruby operations
    config.command_timeout = 5
    config.max_results = 10
  end

  describe '#initialize' do
    it 'initializes with a configuration and safety checker' do
      expect(executor.instance_variable_get(:@config)).to eq(config)
      expect(executor.instance_variable_get(:@safety_checker)).to be_a(RailsActiveMcp::SafetyChecker)
      expect(RailsActiveMcp::ConsoleExecutor::EXECUTION_MUTEX).to be_a(Mutex)
    end
  end

  describe '#execute' do
    context 'with safe code' do
      it 'executes simple arithmetic safely' do
        result = executor.execute('2 + 2')

        expect(result[:success]).to be true
        expect(result[:return_value]).to eq(4)
        expect(result[:return_value_string]).to eq('4')
        expect(result[:execution_time]).to be > 0
        expect(result[:code]).to eq('2 + 2')
      end

      it 'captures output when enabled' do
        result = executor.execute('puts "Hello, World!"', capture_output: true)

        expect(result[:success]).to be true
        expect(result[:output]).to include('Hello, World!')
        expect(result[:return_value]).to be_nil # puts returns nil
      end

      it 'does not capture output when disabled' do
        result = executor.execute('puts "Hello, World!"', capture_output: false)

        expect(result[:success]).to be true
        expect(result[:output]).to be_nil
        expect(result[:return_value]).to be_nil
      end
    end

    context 'with thread safety' do
      it 'handles concurrent executions safely' do
        results = []
        threads = []

        # Create multiple threads executing code concurrently
        5.times do |i|
          threads << Thread.new do
            result = executor.execute("x = #{i}; x * 2")
            results << result
          end
        end

        threads.each(&:join)

        expect(results.length).to eq(5)
        results.each do |result|
          expect(result[:success]).to be true
          expect(result[:return_value]).to be_even
        end
      end

      it 'does not leak state between executions' do
        # First execution sets a variable
        result1 = executor.execute('test_var = "first"')
        expect(result1[:success]).to be true

        # Second execution should not see the variable
        result2 = executor.execute('defined?(test_var) ? test_var : "undefined"')
        expect(result2[:success]).to be true
        expect(result2[:return_value]).to eq('undefined')
      end

      it 'handles stdout capture thread safely' do
        results = []
        threads = []

        5.times do |i|
          threads << Thread.new do
            result = executor.execute("puts 'Thread #{i}'", capture_output: true)
            results << result
          end
        end

        threads.each(&:join)

        results.each do |result|
          expect(result[:success]).to be true
          expect(result[:output]).to match(/Thread \d/)
        end
      end
    end

    context 'with unsafe code' do
      before { config.safe_mode = true }

      it 'blocks dangerous system calls' do
        result = executor.execute('system("ls")', safe_mode: true)

        expect(result[:success]).to be false
        expect(result[:error_class]).to eq('SafetyError')
        expect(result[:error]).to include('safety check')
      end

      it 'blocks file operations' do
        result = executor.execute('File.delete("test.txt")', safe_mode: true)

        expect(result[:success]).to be false
        expect(result[:error_class]).to eq('SafetyError')
        expect(result[:error]).to include('safety check')
      end
    end

    context 'with timeout' do
      it 'respects custom timeout' do
        start_time = Time.now

        expect do
          executor.execute('sleep 10', timeout: 1)
        end.to raise_error(RailsActiveMcp::TimeoutError)

        execution_time = Time.now - start_time
        expect(execution_time).to be < 2 # Should timeout much faster than 10 seconds
      end
    end

    context 'with errors' do
      it 'handles syntax errors gracefully' do
        result = executor.execute('invalid syntax !')

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
        expect(result[:error_class]).to eq('SyntaxError')
        expect(result[:backtrace]).to be_an(Array)
      end

      it 'handles runtime errors gracefully' do
        result = executor.execute('1 / 0')

        expect(result[:success]).to be false
        expect(result[:error]).to include('divided by 0')
        expect(result[:error_class]).to eq('ZeroDivisionError')
      end
    end
  end

  describe '#execute_safe_query' do
    before do
      # Skip these tests if ActiveRecord is not available
      skip 'ActiveRecord not available' unless defined?(ActiveRecord::Base)
    end

    it 'executes safe query methods' do
      allow(String).to receive(:constantize).and_return(double('Model', count: 5))

      result = executor.execute_safe_query(model: 'User', method: 'count')

      expect(result[:success]).to be true
      expect(result[:model]).to eq('User')
      expect(result[:method]).to eq('count')
    end

    it 'blocks unsafe query methods' do
      result = executor.execute_safe_query(model: 'User', method: 'delete_all')

      expect(result[:success]).to be false
      expect(result[:error_class]).to eq('SafetyError')
      expect(result[:error]).to include('not allowed for safe queries')
    end

    it 'blocks access to disallowed models' do
      config.allowed_models = ['User'] # Only allow User model, block SecretModel

      result = executor.execute_safe_query(model: 'SecretModel', method: 'count')

      expect(result[:success]).to be false
      expect(result[:error_class]).to eq('SafetyError')
      expect(result[:error]).to include('not allowed')
    end
  end

  describe '#get_model_info' do
    it 'blocks access to disallowed models' do
      config.allowed_models = ['User']
      result = executor.get_model_info('SecretModel')
      expect(result[:success]).to be false
      expect(result[:error]).to include('not allowed')
    end
  end

  describe '#dry_run' do
    it 'analyzes code without executing' do
      result = executor.dry_run('2 + 2')

      expect(result[:code]).to eq('2 + 2')
      expect(result[:safety_analysis]).to be_a(Hash)
      expect(result[:would_execute]).to be_truthy # Should be true when safe_mode is false
      expect(result[:estimated_risk]).to be_a(Symbol)
      expect(result[:recommendations]).to be_an(Array)
    end

    it 'identifies dangerous code' do
      result = executor.dry_run('system("rm -rf /")')

      expect(result[:safety_analysis][:safe]).to be false
      expect(result[:estimated_risk]).to be_in(%i[critical high])
    end
  end

  describe 'Rails 7.1 compatibility' do
    context 'when Rails is available' do
      before do
        # Mock Rails for testing
        rails_routes = double('Routes', url_helpers: Module.new)
        rails_executor = double('Executor')
        rails_app = double('Application', routes: rails_routes, executor: rails_executor)
        rails_env = double('Environment', development?: false, production?: false)

        stub_const('Rails', double('Rails'))
        allow(Rails).to receive(:application).and_return(rails_app)
        allow(Rails).to receive(:env).and_return(rails_env)
        allow(rails_executor).to receive(:wrap).and_yield
      end

      it 'uses Rails executor when available' do
        mock_executor = double('RailsExecutor')
        allow(Rails.application).to receive(:executor).and_return(mock_executor)
        allow(mock_executor).to receive(:wrap).and_yield

        result = executor.execute('2 + 2')
        expect(result[:success]).to be true
      end

      it 'handles ActiveSupport::Dependencies when available' do
        stub_const('ActiveSupport::Dependencies', double('Dependencies'))
        mock_interlock = double('Interlock')
        allow(ActiveSupport::Dependencies).to receive(:respond_to?).with(:interlock).and_return(true)
        allow(ActiveSupport::Dependencies).to receive(:interlock).and_return(mock_interlock)
        allow(mock_interlock).to receive(:permit_concurrent_loads).and_yield

        mock_executor = double('RailsExecutor')
        allow(Rails.application).to receive(:executor).and_return(mock_executor)
        allow(mock_executor).to receive(:wrap).and_yield

        result = executor.execute('2 + 2')
        expect(result[:success]).to be true
      end
    end

    context 'when ActiveRecord is available' do
      before do
        # Mock Rails for testing
        rails_routes = double('Routes', url_helpers: Module.new)
        rails_executor = double('Executor')
        rails_app = double('Application', routes: rails_routes, executor: rails_executor)
        rails_env = double('Environment', development?: false, production?: false)

        stub_const('Rails', double('Rails'))
        allow(Rails).to receive(:application).and_return(rails_app)
        allow(Rails).to receive(:env).and_return(rails_env)
        allow(rails_executor).to receive(:wrap).and_yield

        # Mock ActiveRecord
        stub_const('::ActiveRecord::Base', double('ActiveRecord'))
        mock_pool = double('ConnectionPool')
        allow(ActiveRecord::Base).to receive(:connection_pool).and_return(mock_pool)
        allow(mock_pool).to receive(:with_connection).and_yield
        allow(mock_pool).to receive(:release_connection)
        allow(mock_pool).to receive(:respond_to?).with(:release_connection).and_return(true)
      end

      it 'manages connection pool properly' do
        expect(ActiveRecord::Base.connection_pool).to receive(:with_connection).and_yield
        expect(ActiveRecord::Base.connection_pool).to receive(:release_connection)

        result = executor.execute('2 + 2')
        expect(result[:success]).to be true
      end
    end
  end

  describe 'thread-safe console binding' do
    it 'creates new binding context for each execution' do
      # Execute code that would affect binding if shared
      result1 = executor.execute('binding.local_variables')
      result2 = executor.execute('test_var = 42; binding.local_variables')

      expect(result1[:success]).to be true
      expect(result2[:success]).to be true
      # Verify isolation - result1 shouldn't see test_var
      expect(result1[:return_value]).not_to include(:test_var)
    end

    it 'provides safe Rails console helpers' do
      result = executor.execute('defined?(app) ? "app available" : "app not available"')
      expect(result[:success]).to be true
      # Should be safe regardless of Rails availability
    end
  end

  describe 'memory management' do
    it 'triggers garbage collection probabilistically' do
      # Mock GC to verify it gets called
      allow(GC).to receive(:start)
      allow(Random).to receive(:rand).with(100).and_return(1) # Force GC trigger

      if defined?(ActiveRecord::Base)
        pool = double('ConnectionPool')
        allow(ActiveRecord::Base).to receive(:connection_pool).and_return(pool)
        allow(pool).to receive(:respond_to?).with(:release_connection).and_return(true)
        allow(pool).to receive(:release_connection)
        expect(GC).to receive(:start)
      end

      executor.execute('2 + 2')
    end
  end

  describe 'development mode reloading' do
    before do
      rails_routes = double('Routes', url_helpers: Module.new)
      rails_reloader = double('Reloader')
      rails_executor = double('Executor')
      rails_app = double('Application', routes: rails_routes, reloader: rails_reloader, executor: rails_executor)
      rails_env = double('Environment', development?: true, production?: false)

      stub_const('Rails', double('Rails'))
      allow(Rails).to receive(:application).and_return(rails_app)
      allow(Rails).to receive(:env).and_return(rails_env)
      allow(rails_executor).to receive(:wrap).and_yield
      allow(rails_reloader).to receive(:check!).and_return(false)
      allow(rails_reloader).to receive(:reload!)
    end

    it 'handles reloading when available' do
      mock_reloader = double('Reloader')
      allow(Rails.application).to receive(:reloader).and_return(mock_reloader)
      allow(mock_reloader).to receive(:check!).and_return(true)
      allow(mock_reloader).to receive(:reload!)

      expect(mock_reloader).to receive(:reload!)

      # This will trigger the reloading through execute_with_rails_executor
      result = executor.execute('2 + 2')
      expect(result[:success]).to be true
    end

    it 'handles reloading errors gracefully' do
      mock_reloader = double('Reloader')
      allow(Rails.application).to receive(:reloader).and_return(mock_reloader)
      allow(mock_reloader).to receive(:check!).and_raise(StandardError.new('Reload failed'))

      # Mock logger to avoid actual logging
      mock_logger = double('Logger')
      allow(RailsActiveMcp).to receive(:logger).and_return(mock_logger)
      allow(mock_logger).to receive(:warn)

      # Should not raise error, just log warning
      result = executor.execute('2 + 2')
      expect(result[:success]).to be true
    end
  end
end
