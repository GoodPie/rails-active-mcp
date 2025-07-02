# frozen_string_literal: true

# Configure SimpleCov before requiring any application code
require 'simplecov'

SimpleCov.start 'rails' do
  # Specify command name for test framework recognition
  command_name 'RSpec'

  # Exclude test files and vendor directories from coverage
  add_filter '/spec/'
  add_filter '/vendor/'
  add_filter '/config/'
  add_filter '/db/'

  # Set minimum coverage threshold
  minimum_coverage 80

  # Generate coverage in multiple formats
  formatter SimpleCov::Formatter::MultiFormatter.new([
                                                       SimpleCov::Formatter::HTMLFormatter,
                                                       SimpleCov::Formatter::SimpleFormatter
                                                     ])

  # Track files in lib directory
  track_files 'lib/**/*.rb'
end

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'

# Set up minimal Rails environment for timezone support
require 'rails'
require 'active_support/all'

# Configure Rails timezone for consistent test behavior
Time.use_zone 'UTC' do
  Rails.app_class = Class.new(Rails::Application) unless defined?(Rails.app_class)
end

# Require RSpec first, then spec_helper
require 'rspec'
require_relative 'spec_helper'

# For gem testing, we'll set up a minimal testing environment
require 'active_record'
require 'factory_bot_rails'
require 'database_cleaner/active_record'
require 'webmock/rspec'
require 'timecop'

# Configure RailsActiveMcp for testing
require 'rails_active_mcp'

# Configure database for testing
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:',
  timeout: 5000
)

RailsActiveMcp.configure do |config|
  # Test-specific configurations
  config.enable_logging = false
  config.log_level = :warn
  config.safe_mode = false # Disable safe mode for testing
  config.command_timeout = 10
  config.max_results = 50
  config.log_executions = false
end

# Set up basic database schema for testing
ActiveRecord::Schema.define do
  # Not required yet
end

# Require migration files if they exist in the gem's generators
migration_paths = [
  File.expand_path('../lib/generators/rails_active_mcp/install/templates/db/migrate', __dir__ || File.dirname(__FILE__))
].select { |path| Dir.exist?(path) }

migration_paths.each do |path|
  Dir[File.join(path, '*.rb')].each { |file| require file }
end

# Add additional requires for supporting files
# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
support_files = File.expand_path('support/**/*.rb', __dir__ || File.dirname(__FILE__))
Dir[support_files].each { |f| require f }

RSpec.configure do |config|
  # Configure DatabaseCleaner
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  # Configure WebMock
  config.before do
    WebMock.reset!
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  # Configure Timecop
  config.after do
    Timecop.return
  end

  # Shared configuration for RailsActiveMcp tests
  config.before(:each, type: :mcp) do
    # Setup MCP-specific test environment
    RailsActiveMcp.reset! if RailsActiveMcp.respond_to?(:reset!)
  end

  # Reset RailsActiveMcp configuration before each test
  config.before do
    RailsActiveMcp.configuration = nil
  end
end
