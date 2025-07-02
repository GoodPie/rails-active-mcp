# noinspection RubyResolve
require 'spec_helper'
require 'rails'
require 'rails/generators/test_case'
require 'rails/generators'
require 'generators/rails_active_mcp/install/install_generator'
require 'fileutils'

RSpec.describe RailsActiveMcp::Generators::InstallGenerator, type: :generator do
  include Rails::Generators::Testing::Behavior
  include Rails::Generators::Testing::Assertions
  include FileUtils

  # Set up destination directory
  destination File.expand_path('../tmp', __dir__ || File.dirname(__FILE__))

  # Specify the generator class
  tests described_class

  before(:all) do
    # Create and clean destination directory
    FileUtils.mkdir_p(destination_root)
  end

  before do
    # Clean destination for each test
    FileUtils.rm_rf(destination_root)
    FileUtils.mkdir_p(destination_root)

    # Mock Rails.root for the generator
    allow(Rails).to receive(:root).and_return(Pathname.new(destination_root))
  end

  describe 'generator execution' do
    before do
      run_generator []
    end

    it 'creates the initializer file' do
      expect(File.exist?(File.join(destination_root, 'config/initializers/rails_active_mcp.rb'))).to be true
    end

    it 'creates a properly configured initializer' do
      initializer_path = File.join(destination_root, 'config/initializers/rails_active_mcp.rb')
      expect(File.exist?(initializer_path)).to be true

      content = File.read(initializer_path)
      expect(content).to include('RailsActiveMcp.configure')
      expect(content).to include('config.allowed_commands')
      expect(content).to include('config.command_timeout')
      expect(content).to include('config.enable_logging')
    end
  end

  describe 'help text' do
    it 'displays the correct description' do
      generator = described_class.new
      expect(generator.class.desc).to eq('Install Rails Active MCP')
    end
  end
end
