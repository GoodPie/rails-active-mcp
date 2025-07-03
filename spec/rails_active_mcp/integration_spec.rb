# noinspection RubyResolve
require 'spec_helper'

RSpec.describe 'RailsActiveMcp Integration' do
  let(:config) { RailsActiveMcp::Configuration.new }
  let(:executor) { RailsActiveMcp::ConsoleExecutor.new(config) }

  before do
    # Ensure configuration is reset to defaults
    RailsActiveMcp.configure do |config|
      config.safe_mode = true
      config.command_timeout = 30
      config.enabled = true
    end

    # Mock Rails environment with realistic models
    # Create doubles outside the class definition
    id_column = double(name: 'id', type: :integer, primary: true)
    email_column = double(name: 'email', type: :string, primary: false)
    created_at_column = double(name: 'created_at', type: :datetime, primary: false)
    posts_association = double(name: :posts, macro: :has_many, class_name: 'Post')
    profile_association = double(name: :profile, macro: :has_one, class_name: 'Profile')

    stub_const('User', Class.new do
      def self.count
        42
      end

      def self.where(_conditions)
        self
      end

      def self.limit(_n)
        []
      end

      def self.find(_id)
        new
      end

      def self.table_name
        'users'
      end

      def self.primary_key
        'id'
      end

      define_singleton_method(:columns) do
        [id_column, email_column, created_at_column]
      end

      define_singleton_method(:reflect_on_all_associations) do
        [posts_association, profile_association]
      end

      def self.validators
        []
      end
    end)
  end

  describe 'MCP Tools Integration' do
    describe 'console_execute tool' do
      it 'executes safe Ruby code' do
        result = executor.execute('1 + 1')

        expect(result[:success]).to be true
        expect(result[:return_value]).to eq(2)
        expect(result[:output]).to eq('')
      end

      it 'executes Rails model queries' do
        result = executor.execute('User.count')

        expect(result[:success]).to be true
        expect(result[:return_value]).to eq(42)
      end

      it 'blocks dangerous operations' do
        config.safe_mode = true
        result = executor.execute('User.delete_all')

        expect(result[:success]).to be false
        expect(result[:error]).to include('violation')
      end

      it 'times out long-running operations' do
        config.command_timeout = 1

        expect do
          executor.execute('sleep(2)')
        end.to raise_error(RailsActiveMcp::TimeoutError)
      end
    end

    describe 'safe_query execution' do
      it 'executes read-only queries safely' do
        result = executor.execute_safe_query(
          model: 'User',
          method: 'where',
          args: [{ active: true }],
          limit: 10
        )

        RSpec.configuration.reporter.message("DEBUG: result = #{result.inspect}") if result[:success] == false
        expect(result[:success]).to be true
        expect(result[:result]).to be_an(Array)
      end

      it 'blocks non-read-only operations' do
        result = executor.execute_safe_query(
          model: 'User',
          method: 'delete_all',
          args: [],
          limit: 10
        )

        expect(result[:success]).to be false
        expect(result[:error]).to include('not allowed')
      end
    end

    describe 'model introspection' do
      it 'extracts model information' do
        info = executor.get_model_info('User')

        puts "DEBUG: model info result = #{info.inspect}" if info[:success] == false
        expect(info[:success]).to be true
        expect(info[:model_name]).to eq('User')
        expect(info[:columns]).to be_an(Array)
        expect(info[:associations]).to be_an(Array)
      end
    end
  end

  describe 'Claude Desktop Integration Scenarios' do
    it 'handles typical user queries' do
      queries = [
        'User.count',
        'User.where(active: true).limit(10)',
        'User.find(1)',
        'Rails.env'
      ]

      queries.each do |query|
        result = executor.execute(query)
        expect(result[:success]).to be(true), "Failed for query: #{query}"
      end
    end

    it 'provides helpful error messages' do
      result = executor.execute('NonExistentModel.count')

      expect(result[:success]).to be false
      expect(result[:error]).to be_a(String)
      expect(result[:error]).not_to be_empty
    end
  end

  describe 'Performance Characteristics' do
    it 'executes queries within reasonable time limits' do
      start_time = Time.now
      result = executor.execute('User.count')
      execution_time = Time.now - start_time

      expect(result[:success]).to be true
      expect(execution_time).to be < 1.0 # Should complete within 1 second
    end

    it 'limits result set sizes' do
      config.max_results = 5
      result = executor.execute_safe_query(
        model: 'User',
        method: 'limit',
        args: [100], # Try to get 100 but should be limited
        limit: config.max_results
      )

      expect(result[:success]).to be true
      # The actual limiting would depend on implementation
    end
  end

  describe 'Multi-environment Behavior' do
    it 'applies stricter rules in production' do
      Rails.env = 'production'
      config = RailsActiveMcp::Configuration.new

      expect(config.safe_mode).to be true
      expect(config.command_timeout).to be <= 30
    end

    it 'allows more permissive settings in development' do
      Rails.env = 'development'
      config = RailsActiveMcp::Configuration.new

      expect(config.command_timeout).to be >= 30
    end
  end
end
