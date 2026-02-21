# frozen_string_literal: true

require 'spec_helper'
require 'rails'
require 'rails/generators'
require 'generators/rails_active_mcp/install/install_generator'
require 'fileutils'
require 'tmpdir'

RSpec.describe RailsActiveMcp::Generators::InstallGenerator, type: :generator do
  let(:destination_root) { Dir.mktmpdir('rails_active_mcp_test') }
  let(:generator) { described_class.new([], {}, destination_root: destination_root) }

  before do
    # Clean destination for each test
    FileUtils.rm_rf(destination_root)
    FileUtils.mkdir_p(destination_root)

    # Create necessary Rails directories
    FileUtils.mkdir_p(File.join(destination_root, 'config', 'initializers'))
    FileUtils.mkdir_p(File.join(destination_root, 'bin'))

    # Mock Rails.root for the generator
    allow(Rails).to receive(:root).and_return(Pathname.new(destination_root))

    # Mock Rails environment
    allow(Rails).to receive(:env).and_return('test')

    # Mock Dir.home for the generator
    allow(Dir).to receive(:home).and_return('/home/test')
  end

  after do
    FileUtils.rm_rf(destination_root)
  end

  describe 'generator execution' do
    before do
      # Silence the generator output and skip interactive prompts
      allow(generator).to receive(:say)
      allow(generator).to receive(:readme)
      allow(generator).to receive(:ask).and_return('')

      # Run the generator
      generator.invoke_all
    end

    it 'creates the initializer file' do
      expect(File.exist?(File.join(destination_root, 'config/initializers/rails_active_mcp.rb'))).to be true
    end

    # rubocop:disable RSpec/MultipleExpectations
    it 'creates a properly configured initializer' do
      initializer_path = File.join(destination_root, 'config/initializers/rails_active_mcp.rb')
      expect(File.exist?(initializer_path)).to be true

      content = File.read(initializer_path)
      expect(content).to include('RailsActiveMcp.configure')
      expect(content).to include('config.command_timeout')
      expect(content).to include('config.enable_logging')
      expect(content).to include('config.safe_mode')
      expect(content).to include('config.max_results')
    end
    # rubocop:enable RSpec/MultipleExpectations

    it 'creates the wrapper script' do
      wrapper_path = File.join(destination_root, 'bin/rails-active-mcp-wrapper')
      expect(File.exist?(wrapper_path)).to be true
      expect(File.executable?(wrapper_path)).to be true
    end

    it 'creates the server script' do
      server_path = File.join(destination_root, 'bin/rails-active-mcp-server')
      expect(File.exist?(server_path)).to be true
      expect(File.executable?(server_path)).to be true
    end

    it 'creates the mcp.ru file' do
      mcp_ru_path = File.join(destination_root, 'mcp.ru')
      expect(File.exist?(mcp_ru_path)).to be true

      content = File.read(mcp_ru_path)
      expect(content).to include('require_relative \'config/environment\'')
      expect(content).to include('require \'rails_active_mcp/sdk/server\'')
    end

    it 'creates wrapper script with correct content' do
      wrapper_path = File.join(destination_root, 'bin/rails-active-mcp-wrapper')
      content = File.read(wrapper_path)

      expect(content).to include('#!/usr/bin/env bash')
      expect(content).to include('Rails Active MCP Wrapper Script')
      expect(content).to include('USER_SHELL')
      expect(content).to include('bundle exec rails-active-mcp-server')
    end

    it 'creates server script with correct content' do
      server_path = File.join(destination_root, 'bin/rails-active-mcp-server')
      content = File.read(server_path)

      expect(content).to include('#!/usr/bin/env ruby')
      expect(content).to include('Rails Active MCP Server Script')
      expect(content).to include('require_relative \'../config/environment\'')
      expect(content).to include('require \'rails_active_mcp\'')
    end
  end

  describe 'MCP client config generation' do
    before do
      allow(generator).to receive(:say)
      allow(generator).to receive(:readme)
    end

    context 'when user selects Claude Code' do
      before do
        allow(generator).to receive(:ask).and_return('1')
        generator.invoke_all
      end

      it 'creates .mcp.json' do
        config_path = File.join(destination_root, '.mcp.json')
        expect(File.exist?(config_path)).to be true
      end

      it 'creates .mcp.json with correct structure' do
        config_path = File.join(destination_root, '.mcp.json')
        config = JSON.parse(File.read(config_path))

        expect(config).to have_key('mcpServers')
        expect(config['mcpServers']).to have_key('rails-active-mcp')
        expect(config['mcpServers']['rails-active-mcp']['command']).to include('bin/rails-active-mcp-wrapper')
      end
    end

    context 'when user selects Cursor' do
      before do
        allow(generator).to receive(:ask).and_return('2')
        generator.invoke_all
      end

      it 'creates .cursor/mcp.json' do
        config_path = File.join(destination_root, '.cursor/mcp.json')
        expect(File.exist?(config_path)).to be true
      end

      it 'uses mcpServers key' do
        config_path = File.join(destination_root, '.cursor/mcp.json')
        config = JSON.parse(File.read(config_path))
        expect(config).to have_key('mcpServers')
      end
    end

    context 'when user selects VS Code' do
      before do
        allow(generator).to receive(:ask).and_return('3')
        generator.invoke_all
      end

      it 'creates .vscode/mcp.json' do
        config_path = File.join(destination_root, '.vscode/mcp.json')
        expect(File.exist?(config_path)).to be true
      end

      it 'uses servers key for VS Code format' do
        config_path = File.join(destination_root, '.vscode/mcp.json')
        config = JSON.parse(File.read(config_path))
        expect(config).to have_key('servers')
      end
    end

    context 'when user selects multiple clients' do
      before do
        allow(generator).to receive(:ask).and_return('1,2,3')
        generator.invoke_all
      end

      it 'creates config files for all selected clients' do
        expect(File.exist?(File.join(destination_root, '.mcp.json'))).to be true
        expect(File.exist?(File.join(destination_root, '.cursor/mcp.json'))).to be true
        expect(File.exist?(File.join(destination_root, '.vscode/mcp.json'))).to be true
      end
    end

    context 'when user skips client selection' do
      before do
        allow(generator).to receive(:ask).and_return('6')
        generator.invoke_all
      end

      it 'does not create any client config files' do
        expect(File.exist?(File.join(destination_root, '.mcp.json'))).to be false
        expect(File.exist?(File.join(destination_root, '.cursor/mcp.json'))).to be false
        expect(File.exist?(File.join(destination_root, '.vscode/mcp.json'))).to be false
      end
    end

    context 'when user enters empty response' do
      before do
        allow(generator).to receive(:ask).and_return('')
        generator.invoke_all
      end

      it 'does not create any client config files' do
        expect(File.exist?(File.join(destination_root, '.mcp.json'))).to be false
        expect(File.exist?(File.join(destination_root, '.cursor/mcp.json'))).to be false
        expect(File.exist?(File.join(destination_root, '.vscode/mcp.json'))).to be false
      end
    end

    context 'when .mcp.json already exists with other servers' do
      let(:existing_config) do
        {
          'mcpServers' => {
            'some-other-server' => { 'command' => 'other-cmd', 'args' => [] }
          }
        }
      end

      before do
        File.write(File.join(destination_root, '.mcp.json'), JSON.pretty_generate(existing_config))
        allow(generator).to receive(:ask).and_return('1')
        generator.invoke_all
      end

      it 'preserves existing servers' do
        config = JSON.parse(File.read(File.join(destination_root, '.mcp.json')))
        expect(config['mcpServers']).to have_key('some-other-server')
      end

      it 'adds rails-active-mcp alongside existing servers' do
        config = JSON.parse(File.read(File.join(destination_root, '.mcp.json')))
        expect(config['mcpServers']).to have_key('rails-active-mcp')
      end
    end

    context 'when .mcp.json already has rails-active-mcp configured' do
      let(:existing_config) do
        {
          'mcpServers' => {
            'rails-active-mcp' => { 'command' => 'old-cmd', 'args' => ['--old'] }
          }
        }
      end

      before do
        File.write(File.join(destination_root, '.mcp.json'), JSON.pretty_generate(existing_config))
        allow(generator).to receive(:ask).and_return('1')
        generator.invoke_all
      end

      it 'does not overwrite the existing entry' do
        config = JSON.parse(File.read(File.join(destination_root, '.mcp.json')))
        expect(config['mcpServers']['rails-active-mcp']['command']).to eq('old-cmd')
      end
    end

    context 'when existing config file has invalid JSON' do
      before do
        File.write(File.join(destination_root, '.mcp.json'), 'not valid json{{{')
        allow(generator).to receive(:ask).and_return('1')
        generator.invoke_all
      end

      it 'does not crash and leaves the file unchanged' do
        content = File.read(File.join(destination_root, '.mcp.json'))
        expect(content).to eq('not valid json{{{')
      end
    end
  end

  describe 'help text' do
    it 'displays the correct description' do
      expect(described_class.desc).to eq('Install Rails Active MCP')
    end
  end

  describe 'template validation' do
    it 'has valid initializer template' do
      template_path = File.join(described_class.source_root, 'initializer.rb')
      expect(File.exist?(template_path)).to be true

      content = File.read(template_path)
      expect(content).to include('RailsActiveMcp.configure')
      expect(content).to be_valid_ruby_syntax
    end

    it 'has valid wrapper template' do
      template_path = File.join(described_class.source_root, 'rails-active-mcp-wrapper')
      expect(File.exist?(template_path)).to be true

      content = File.read(template_path)
      expect(content).to include('#!/usr/bin/env bash')
    end

    it 'has valid server template' do
      template_path = File.join(described_class.source_root, 'rails-active-mcp-server')
      expect(File.exist?(template_path)).to be true

      content = File.read(template_path)
      expect(content).to include('#!/usr/bin/env ruby')
      expect(content).to be_valid_ruby_syntax
    end
  end

  describe 'file permissions' do
    before do
      allow(generator).to receive(:say)
      allow(generator).to receive(:readme)
      allow(generator).to receive(:ask).and_return('')
      generator.invoke_all
    end

    it 'sets executable permissions on wrapper script' do
      wrapper_path = File.join(destination_root, 'bin/rails-active-mcp-wrapper')
      expect(File.executable?(wrapper_path)).to be true
    end

    it 'sets executable permissions on server script' do
      server_path = File.join(destination_root, 'bin/rails-active-mcp-server')
      expect(File.executable?(server_path)).to be true
    end
  end
end

# Custom matcher for Ruby syntax validation
RSpec::Matchers.define :be_valid_ruby_syntax do
  match do |content|
    # For Ruby files, check syntax
    if content.start_with?('#!/usr/bin/env ruby') || content.include?('require')
      begin
        # Create a temporary file to check syntax
        temp_file = Tempfile.new(['syntax_check', '.rb'])
        temp_file.write(content)
        temp_file.close

        result = system("ruby -c #{temp_file.path} > /dev/null 2>&1")
        temp_file.unlink
        result
      rescue StandardError
        false
      end
    else
      # For non-Ruby files, just check they're not empty
      !content.strip.empty?
    end
  end

  failure_message do |_content|
    'Expected content to be valid Ruby syntax, but it contains syntax errors'
  end
end
