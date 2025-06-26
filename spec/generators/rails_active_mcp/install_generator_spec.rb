require 'spec_helper'
require 'rails'
require 'rails/generators/test_case'
require 'rails/generators'
require 'generators/rails_active_mcp/install/install_generator'

RSpec.describe RailsActiveMcp::Generators::InstallGenerator, type: :generator do
  include Rails::Generators::Testing::Behaviour

  # Set up the generator test environment
  before(:all) do
    # Create a temporary Rails app structure
    @destination = File.expand_path('../../tmp/generated_app', __dir__)
    FileUtils.mkdir_p(@destination)
    Rails.application = double('Rails::Application')
    allow(Rails.application).to receive(:routes).and_return(double('Routes', url_helpers: Module.new))
  end

  after(:all) do
    # Clean up
    FileUtils.rm_rf(@destination) if File.exist?(@destination)
  end

  destination @destination

  before do
    prepare_destination
  end

  describe 'generator execution' do
    before do
      run_generator
    end

    it 'creates the initializer file' do
      expect(file('config/initializers/rails_active_mcp.rb')).to exist
    end

    it 'creates the mcp.ru file' do
      expect(file('mcp.ru')).to exist
    end

    it 'adds the mount route' do
      expect(file('config/routes.rb')).to contain('mount RailsActiveMcp::McpServer.new, at: \'/mcp\'')
    end

    it 'creates a properly configured initializer' do
      initializer_content = file('config/initializers/rails_active_mcp.rb')
      expect(initializer_content).to contain('RailsActiveMcp.configure')
      expect(initializer_content).to contain('config.enabled = true')
    end

    it 'creates a working mcp.ru file' do
      mcp_content = file('mcp.ru')
      expect(mcp_content).to contain('run RailsActiveMcp::McpServer.new')
    end
  end

  describe 'help text' do
    it 'displays the correct description' do
      generator = described_class.new
      expect(generator.class.desc).to eq('Install Rails Active MCP')
    end
  end

  private

  def file(path)
    File.new(File.join(@destination, path)) if File.exist?(File.join(@destination, path))
  end
end
