require 'spec_helper'
require 'rails'
require 'rails/generators/test_case'
require 'rails/generators'
require 'generators/rails_active_mcp/install/install_generator'
require 'fileutils'

RSpec.describe RailsActiveMcp::Generators::InstallGenerator, type: :generator do
  include Rails::Generators::Testing::Behavior

  # Set up the generator test environment
  before(:all) do
    # Create a temporary Rails app structure
    @destination = File.expand_path('../../tmp/generated_app', __dir__)
    FileUtils.mkdir_p(@destination)
    FileUtils.mkdir_p(File.join(@destination, 'config'))
    FileUtils.mkdir_p(File.join(@destination, 'config', 'initializers'))
    FileUtils.mkdir_p(File.join(@destination, 'bin'))
  end

  before do
    # Mock Rails application and root
    Rails.application = double('Rails::Application')
    allow(Rails.application).to receive(:routes).and_return(double('Routes', url_helpers: Module.new))
    allow(Rails).to receive(:root).and_return(Pathname.new(@destination))

    # Create basic files that the generator expects
    File.write(File.join(@destination, 'config', 'routes.rb'), "Rails.application.routes.draw do\nend\n")
  end

  after(:all) do
    # Clean up
    FileUtils.rm_rf(@destination) if File.exist?(@destination)
  end

  destination @destination

  before do
    # Clear destination before each test
    FileUtils.rm_rf(Dir.glob(File.join(@destination, '*')))
    FileUtils.mkdir_p(File.join(@destination, 'config'))
    FileUtils.mkdir_p(File.join(@destination, 'config', 'initializers'))
    FileUtils.mkdir_p(File.join(@destination, 'bin'))
    File.write(File.join(@destination, 'config', 'routes.rb'), "Rails.application.routes.draw do\nend\n")
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

    it 'creates the binstub files' do
      expect(file('bin/rails-active-mcp-server')).to exist
      expect(file('bin/rails-active-mcp-wrapper')).to exist
    end

    it 'creates a properly configured initializer' do
      initializer_content = file_content('config/initializers/rails_active_mcp.rb')
      expect(initializer_content).to include('RailsActiveMcp.configure')
      expect(initializer_content).to include('config.allowed_commands')
      expect(initializer_content).to include('config.command_timeout')
      expect(initializer_content).to include('config.enable_logging')
    end

    it 'creates a working mcp.ru file' do
      mcp_content = file_content('mcp.ru')
      expect(mcp_content).to include('RailsActiveMcp::SDK::Server.new')
      expect(mcp_content).to include('server.run')
    end

    it 'creates executable binstub files' do
      binstub_path = File.join(@destination, 'bin/rails-active-mcp-server')
      wrapper_path = File.join(@destination, 'bin/rails-active-mcp-wrapper')

      expect(File.executable?(binstub_path)).to be true
      expect(File.executable?(wrapper_path)).to be true
    end

    it 'creates binstub with correct SDK server reference' do
      binstub_content = file_content('bin/rails-active-mcp-server')
      expect(binstub_content).to include('RailsActiveMcp::SDK::Server.new')
      expect(binstub_content).to include('server.run')
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
    full_path = File.join(@destination, path)
    File.exist?(full_path) ? full_path : nil
  end

  def file_content(path)
    full_path = File.join(@destination, path)
    File.exist?(full_path) ? File.read(full_path) : nil
  end
end
