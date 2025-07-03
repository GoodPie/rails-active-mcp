# frozen_string_literal: true

# Generator testing support for Rails Active MCP
# This module provides helper methods for testing Rails generators

module GeneratorTesting
  extend ActiveSupport::Concern

  included do
    # Set up temporary directories for generator testing
    let(:generator_destination) { File.expand_path('tmp/generator_test', __dir__) }
  end

  # Helper method to prepare destination directory
  def prepare_generator_destination
    FileUtils.rm_rf(generator_destination) if File.exist?(generator_destination)
    FileUtils.mkdir_p(generator_destination)
  end

  # Helper method to clean up destination directory
  def cleanup_generator_destination
    FileUtils.rm_rf(generator_destination) if File.exist?(generator_destination)
  end

  # Helper method to create a Rails-like directory structure
  def create_rails_app_structure
    %w[
      app/models
      app/controllers
      app/views
      config/initializers
      config/environments
      db/migrate
      lib
      spec
      test
    ].each do |dir|
      FileUtils.mkdir_p(File.join(generator_destination, dir))
    end

    # Create a minimal Rails application file
    app_file = File.join(generator_destination, 'config/application.rb')
    File.write(app_file, <<~RUBY)
      require_relative 'boot'
      require 'rails/all'

      module TestApp
        class Application < Rails::Application
          config.load_defaults 7.0
        end
      end
    RUBY

    # Create a minimal environment file
    env_file = File.join(generator_destination, 'config/environments/test.rb')
    File.write(env_file, <<~RUBY)
      Rails.application.configure do
        config.cache_classes = true
        config.eager_load = false
        config.public_file_server.enabled = true
        config.consider_all_requests_local = true
        config.action_controller.perform_caching = false
        config.action_dispatch.show_exceptions = false
        config.action_controller.allow_forgery_protection = false
        config.active_support.deprecation = :stderr
      end
    RUBY
  end

  # Helper method to run a generator with proper setup
  def run_generator_with_setup(generator_class, args = [])
    prepare_generator_destination
    create_rails_app_structure

    # Mock Rails.root to point to our test directory
    allow(Rails).to receive(:root).and_return(Pathname.new(generator_destination))

    # Create and configure the generator
    generator = generator_class.new(args)
    generator.destination_root = generator_destination

    # Capture output
    output = capture_generator_output { generator.invoke_all }

    { generator: generator, output: output }
  end

  # Helper method to capture generator output
  def capture_generator_output
    original_stdout = $stdout
    original_stderr = $stderr

    $stdout = StringIO.new
    $stderr = StringIO.new

    yield

    {
      stdout: $stdout.string,
      stderr: $stderr.string
    }
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
  end

  # Helper method to read generated file content
  def read_generated_file(relative_path)
    file_path = File.join(generator_destination, relative_path)
    return nil unless File.exist?(file_path)

    File.read(file_path)
  end

  # Helper method to check if a file was generated
  def generated_file_exists?(relative_path)
    File.exist?(File.join(generator_destination, relative_path))
  end

  # Helper method to assert file content matches expectations
  def assert_generated_file_content(relative_path, expected_content)
    content = read_generated_file(relative_path)
    expect(content).not_to be_nil, "Expected file #{relative_path} to be generated"

    case expected_content
    when String
      expect(content).to include(expected_content)
    when Array
      expected_content.each do |expected|
        expect(content).to include(expected)
      end
    when Regexp
      expect(content).to match(expected_content)
    when Hash
      expected_content.each do |key, value|
        case value
        when String
          expect(content).to include(value)
        when Regexp
          expect(content).to match(value)
        end
      end
    end
  end
end

# Configure RSpec to use the generator testing helpers
RSpec.configure do |config|
  config.include GeneratorTesting, type: :generator

  # Clean up after generator tests
  config.after(:each, type: :generator) do
    cleanup_generator_destination if respond_to?(:cleanup_generator_destination)
  end
end
