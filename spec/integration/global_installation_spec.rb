# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'ostruct'
require 'rails_active_mcp/cli'

RSpec.describe 'Global Installation Integration' do
  let(:temp_dir) { Dir.mktmpdir('rails-mcp-test') }
  let(:rails_project_path) { File.join(temp_dir, 'test_rails_app') }
  let(:cli) { RailsActiveMcp::CLI.new }

  before do
    create_mock_rails_project(rails_project_path)
  end

  after do
    FileUtils.rm_rf(temp_dir) if temp_dir && File.exist?(temp_dir)
    # Clean up any global config created during tests
    global_config_path = File.expand_path('~/.config/rails_active_mcp/config.json')
    FileUtils.rm_f(global_config_path)
  end

  describe 'project auto-detection' do
    it 'finds Rails project from subdirectory' do
      subdirectory = File.join(rails_project_path, 'app', 'models')
      FileUtils.mkdir_p(subdirectory)

      Dir.chdir(subdirectory) do
        detected_path = RailsActiveMcp::ProjectUtils.find_rails_root
        expect(File.realpath(detected_path)).to eq(File.realpath(rails_project_path))
      end
    end

    it 'finds Rails project from nested subdirectory' do
      deep_subdirectory = File.join(rails_project_path, 'app', 'models', 'concerns')
      FileUtils.mkdir_p(deep_subdirectory)

      Dir.chdir(deep_subdirectory) do
        detected_path = RailsActiveMcp::ProjectUtils.find_rails_root
        expect(File.realpath(detected_path)).to eq(File.realpath(rails_project_path))
      end
    end

    it 'returns nil when no Rails project found' do
      non_rails_dir = File.join(temp_dir, 'not_rails')
      FileUtils.mkdir_p(non_rails_dir)

      Dir.chdir(non_rails_dir) do
        detected_path = RailsActiveMcp::ProjectUtils.find_rails_root
        expect(detected_path).to be_nil
      end
    end

    it 'handles explicit project path correctly' do
      options = { project: rails_project_path }
      detected_path = RailsActiveMcp::ProjectUtils.determine_rails_path(options)
      expect(detected_path).to eq(rails_project_path)
    end

    it 'handles invalid explicit project path' do
      invalid_path = File.join(temp_dir, 'nonexistent')
      options = { project: invalid_path }
      detected_path = RailsActiveMcp::ProjectUtils.determine_rails_path(options)
      expect(detected_path).to be_nil
    end

    it 'handles auto-detect option from current directory' do
      Dir.chdir(rails_project_path) do
        options = { auto_detect: true }
        detected_path = RailsActiveMcp::ProjectUtils.determine_rails_path(options)
        expect(File.realpath(detected_path)).to eq(File.realpath(rails_project_path))
      end
    end
  end

  describe 'configuration file loading and precedence' do
    let(:global_config_dir) { File.expand_path('~/.config/rails_active_mcp') }
    let(:global_config_path) { File.join(global_config_dir, 'config.json') }
    let(:project_config_path) { File.join(rails_project_path, 'config', 'rails_active_mcp.json') }

    before do
      FileUtils.mkdir_p(global_config_dir)
    end

    after do
      FileUtils.rm_rf(global_config_dir)
    end

    it 'loads defaults when no config files exist' do
      config = RailsActiveMcp::Configuration.new(rails_project_path)

      expect(config.safe_mode).to be true
      expect(config.command_timeout).to eq(30)
      expect(config.log_level).to eq(:info)
      expect(config.max_results).to eq(100)
    end

    it 'loads global config when present' do
      global_config = {
        safe_mode: false,
        command_timeout: 60,
        log_level: 'debug',
        max_results: 200
      }
      File.write(global_config_path, JSON.pretty_generate(global_config))

      config = RailsActiveMcp::Configuration.new(rails_project_path)

      expect(config.safe_mode).to be false
      expect(config.command_timeout).to eq(60)
      expect(config.log_level).to eq(:debug)
      expect(config.max_results).to eq(200)
    end

    it 'project config overrides global config' do
      global_config = {
        safe_mode: false,
        command_timeout: 60,
        max_results: 200
      }
      File.write(global_config_path, JSON.pretty_generate(global_config))

      project_config = {
        safe_mode: true,
        command_timeout: 45
      }
      File.write(project_config_path, JSON.pretty_generate(project_config))

      config = RailsActiveMcp::Configuration.new(rails_project_path)

      expect(config.safe_mode).to be true # Overridden by project config
      expect(config.command_timeout).to eq(45) # Overridden by project config
      expect(config.max_results).to eq(200) # From global config
    end

    it 'environment variables override file-based config' do
      global_config = {
        safe_mode: false,
        command_timeout: 60
      }
      File.write(global_config_path, JSON.pretty_generate(global_config))

      ENV['RAILS_MCP_SAFE_MODE'] = 'true'
      ENV['RAILS_MCP_TIMEOUT'] = '90'

      config = RailsActiveMcp::Configuration.new(rails_project_path)

      expect(config.safe_mode).to be true # From environment variable
      expect(config.command_timeout).to eq(90) # From environment variable

      # Clean up environment variables
      ENV.delete('RAILS_MCP_SAFE_MODE')
      ENV.delete('RAILS_MCP_TIMEOUT')
    end

    it 'handles malformed JSON config gracefully' do
      File.write(global_config_path, '{invalid json}')

      expect do
        config = RailsActiveMcp::Configuration.new(rails_project_path)
        expect(config.safe_mode).to be true # Should fall back to defaults
      end.not_to raise_error
    end
  end

  describe 'CLI argument processing' do
    it 'processes start command with auto-detect' do
      Dir.chdir(rails_project_path) do
        # Capture the CLI processing without actually starting the server
        allow_any_instance_of(RailsActiveMcp::CLI).to receive(:start_server)

        expect do
          cli.invoke(:start, [], { auto_detect: true, dry_run: true })
        end.not_to raise_error
      end
    end

    it 'processes start command with explicit project path' do
      allow_any_instance_of(RailsActiveMcp::CLI).to receive(:start_server)

      expect do
        cli.invoke(:start, [], { project: rails_project_path, dry_run: true })
      end.not_to raise_error
    end

    it 'handles invalid project path gracefully' do
      invalid_path = File.join(temp_dir, 'nonexistent')

      expect do
        cli.invoke(:start, [], { project: invalid_path })
      end.to raise_error(SystemExit)
    end

    it 'processes CLI options correctly' do
      allow_any_instance_of(RailsActiveMcp::CLI).to receive(:start_server)

      expect do
        cli.invoke(:start, [], {
                     project: rails_project_path,
                     safe_mode: false,
                     timeout: 120,
                     log_level: 'debug',
                     dry_run: true
                   })
      end.not_to raise_error
    end
  end

  describe 'validator functionality' do
    it 'validates valid Rails project' do
      validator = RailsActiveMcp::ProjectValidator.new(rails_project_path)
      results = validator.validate

      expect(results[:valid]).to be true
      expect(results[:project_path]).to eq(rails_project_path)
      expect(results[:checks]).to be_an(Array)
      expect(results[:checks].length).to be > 0

      # Check that we have the expected validation checks
      check_names = results[:checks].map { |check| check[:name] }
      expect(check_names).to include('Rails Application Structure')
      expect(check_names).to include('Gemfile')
      expect(check_names).to include('Rails Dependency')
    end

    it 'validates invalid project' do
      invalid_project = File.join(temp_dir, 'not_rails')
      FileUtils.mkdir_p(invalid_project)

      validator = RailsActiveMcp::ProjectValidator.new(invalid_project)
      results = validator.validate

      expect(results[:valid]).to be false
      expect(results[:project_path]).to eq(invalid_project)

      # Should have errors for missing Rails structure
      error_checks = results[:checks].select { |check| check[:status] == :error }
      expect(error_checks.length).to be > 0
    end

    it 'generates JSON output correctly' do
      validator = RailsActiveMcp::ProjectValidator.new(rails_project_path)
      json_output = validator.validate_json

      expect do
        parsed = JSON.parse(json_output)
        expect(parsed).to have_key('valid')
        expect(parsed).to have_key('project_path')
        expect(parsed).to have_key('checks')
        expect(parsed).to have_key('summary')
        expect(parsed).to have_key('timestamp')
      end.not_to raise_error
    end

    it 'integrates with CLI validate_project command' do
      expect do
        cli.invoke(:validate_project, [], { project: rails_project_path })
      end.not_to raise_error
    end

    it 'handles CLI validate_project with JSON output' do
      output = capture_stdout do
        cli.invoke(:validate_project, [], { project: rails_project_path, json: true })
      end

      expect do
        parsed = JSON.parse(output)
        expect(parsed).to have_key('valid')
      end.not_to raise_error
    end
  end

  describe 'dry-run mode output format' do
    it 'displays configuration in dry-run mode' do
      output = capture_stdout do
        cli.invoke(:start, [], { project: rails_project_path, dry_run: true })
      end

      expect(output).to include('Rails Active MCP Server Configuration')
      expect(output).to include('Rails Project:')
      expect(output).to include('Configuration Sources:')
      expect(output).to include('Current Configuration:')
      expect(output).to include('Server would start with these settings.')
    end

    it 'shows configuration sources correctly' do
      output = capture_stdout do
        cli.invoke(:start, [], { project: rails_project_path, dry_run: true })
      end

      expect(output).to include('Global config:')
      expect(output).to include('Project config:')
      expect(output).to include('Environment variables:')
      expect(output).to include('CLI options:')
    end

    it 'displays CLI options when provided' do
      output = capture_stdout do
        cli.invoke(:start, [], {
                     project: rails_project_path,
                     safe_mode: false,
                     timeout: 120,
                     log_level: 'debug',
                     dry_run: true
                   })
      end

      expect(output).to include('--safe-mode false')
      expect(output).to include('--timeout 120')
      expect(output).to include('--log-level debug')
      expect(output).to include('--project')
    end
  end

  describe 'generate_config command' do
    it 'generates configuration file successfully' do
      config_file = File.join(rails_project_path, 'config', 'rails_active_mcp.json')

      # Ensure config file doesn't exist
      FileUtils.rm_f(config_file)

      # Mock user input for overwrite confirmation
      allow(cli).to receive(:yes?).and_return(true)

      expect do
        cli.invoke(:generate_config, [], { project: rails_project_path })
      end.not_to raise_error

      expect(File.exist?(config_file)).to be true

      # Verify the generated config is valid JSON
      expect do
        config_content = JSON.parse(File.read(config_file))
        expect(config_content).to have_key('safe_mode')
        expect(config_content).to have_key('command_timeout')
        expect(config_content).to have_key('allowed_commands')
      end.not_to raise_error
    end

    it 'handles existing configuration file' do
      config_file = File.join(rails_project_path, 'config', 'rails_active_mcp.json')

      # Create existing config file
      File.write(config_file, '{"existing": true}')

      # Mock user declining to overwrite
      allow(cli).to receive(:yes?).and_return(false)

      output = capture_stdout do
        cli.invoke(:generate_config, [], { project: rails_project_path })
      end

      expect(output).to include('Configuration file already exists')
    end
  end

  describe 'error handling' do
    it 'handles permission denied errors gracefully' do
      # Create a directory we can't read
      restricted_dir = File.join(temp_dir, 'restricted')
      FileUtils.mkdir_p(restricted_dir)
      FileUtils.chmod(0o000, restricted_dir)

      begin
        detected_path = RailsActiveMcp::ProjectUtils.find_rails_root(restricted_dir)
        expect(detected_path).to be_nil
      ensure
        # Clean up - restore permissions so we can delete
        FileUtils.chmod(0o755, restricted_dir)
      end
    end

    it 'handles non-existent paths gracefully' do
      non_existent = File.join(temp_dir, 'does_not_exist')
      detected_path = RailsActiveMcp::ProjectUtils.find_rails_root(non_existent)
      expect(detected_path).to be_nil
    end

    it 'validates project path security' do
      # Test path traversal protection
      malicious_path = '../../../etc'
      validated_path = RailsActiveMcp::ProjectUtils.validate_project_path(malicious_path)

      # Should either be nil or a safe absolute path
      if validated_path
        expect(validated_path).to start_with('/')
        expect(validated_path).not_to include('..')
      end
    end
  end

  private

  def create_mock_rails_project(path)
    FileUtils.mkdir_p(File.join(path, 'config'))
    FileUtils.mkdir_p(File.join(path, 'app', 'models'))
    FileUtils.mkdir_p(File.join(path, 'app', 'views'))
    FileUtils.mkdir_p(File.join(path, 'app', 'controllers'))

    # Create minimal boot.rb
    File.write(File.join(path, 'config', 'boot.rb'), <<~RUBY)
      ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)
      # Mock Rails boot file for testing
    RUBY

    # Create minimal Rails application.rb
    File.write(File.join(path, 'config', 'application.rb'), <<~RUBY)
      require_relative 'boot'
      # Mock Rails application for testing

      module TestApp
        class Application
          def self.load_defaults(version)
            # Mock method
          end

          def self.config
            @config ||= OpenStruct.new
          end
        end
      end
    RUBY

    # Create Gemfile with Rails dependency
    File.write(File.join(path, 'Gemfile'), <<~GEMFILE)
      source 'https://rubygems.org'
      git_source(:github) { |repo| "https://github.com/\#{repo}.git" }

      ruby '3.0.0'

      gem 'rails', '~> 7.0'
      gem 'sqlite3', '~> 1.4'
    GEMFILE

    # Create database configuration
    File.write(File.join(path, 'config', 'database.yml'), <<~YAML)
      default: &default
        adapter: sqlite3
        pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
        timeout: 5000

      development:
        <<: *default
        database: db/development.sqlite3

      test:
        <<: *default
        database: db/test.sqlite3

      production:
        <<: *default
        database: db/production.sqlite3
    YAML

    # Create minimal environment.rb
    File.write(File.join(path, 'config', 'environment.rb'), <<~RUBY)
      # Load the Rails application.
      require_relative 'application'

      # Initialize the Rails application.
      Rails.application.initialize!
    RUBY

    # Create routes.rb
    File.write(File.join(path, 'config', 'routes.rb'), <<~RUBY)
      Rails.application.routes.draw do
        # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
      end
    RUBY
  end

  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
