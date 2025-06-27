require 'bundler/setup'
require 'logger'
require 'pathname'
Bundler.setup

require 'rails_active_mcp'

# Configure RSpec
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = 'doc' if config.files_to_run.one?

  config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed

  # Reset configuration before each test
  config.before(:each) do
    RailsActiveMcp.configuration = nil
  end
end

# Mock Rails environment for testing
require 'active_support/string_inquirer'

module Rails
  def self.env
    @env ||= ActiveSupport::StringInquirer.new('test')
  end

  def self.env=(environment)
    @env = ActiveSupport::StringInquirer.new(environment.to_s)
  end

  def self.root
    Pathname.new(Dir.pwd)
  end

  def self.logger
    @logger ||= Logger.new('/dev/null')
  end
end
