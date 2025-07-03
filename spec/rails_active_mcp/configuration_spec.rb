# frozen_string_literal: true

# noinspection RubyResolve
require 'spec_helper'

RSpec.describe RailsActiveMcp::Configuration do
  let(:config) { described_class.new }

  describe 'initialization', :initialization do
    it 'sets safe_mode to default to true' do
      expect(config.safe_mode).to be true
    end

    it 'sets max_results to default to 100' do
      expect(config.max_results).to eq(100)
    end

    it 'sets command_timeout to default to 30' do
      expect(config.command_timeout).to eq(30)
    end

    it 'sets log_executions to default to false' do
      expect(config.log_executions).to be false
    end

    it 'sets enable_logging to default to true' do
      expect(config.enable_logging).to be true
    end

    it 'sets log_level to default to :info' do
      expect(config.log_level).to eq(:info)
    end

    it 'sets allowed_commands to default to an array' do
      expect(config.allowed_commands).to be_an(Array)
      expect(config.allowed_commands).not_to be_empty
    end

    it 'sets allowed_models to default to an empty array' do
      expect(config.allowed_models).to be_an(Array)
      expect(config.allowed_models).to be_empty
    end
  end

  describe 'validation', :validation do
    it 'validates max_results must be positive' do
      config.max_results = 0
      expect { config.validate? }.to raise_error(ArgumentError, /max_results must be positive/)
    end

    it 'validates max_results must be positive when negative' do
      config.max_results = -1
      expect { config.validate? }.to raise_error(ArgumentError, /max_results must be positive/)
    end

    it 'validates command_timeout must be positive' do
      config.command_timeout = 0
      expect { config.validate? }.to raise_error(ArgumentError, /command_timeout must be positive/)
    end

    it 'validates command_timeout must be positive when negative' do
      config.command_timeout = -1
      expect { config.validate? }.to raise_error(ArgumentError, /command_timeout must be positive/)
    end

    it 'validates log_level must be a valid level' do
      config.log_level = :invalid
      expect { config.validate? }.to raise_error(ArgumentError, /log_level must be one of/)
    end

    it 'validates safe_mode must be a boolean' do
      config.safe_mode = 'not_boolean'
      expect { config.validate? }.to raise_error(ArgumentError, /safe_mode must be a boolean/)
    end

    it 'validates allowed_commands must be an array' do
      config.allowed_commands = 'not_array'
      expect { config.validate? }.to raise_error(ArgumentError, /allowed_commands must be an array/)
    end

    it 'passes validation with valid configuration' do
      expect { config.validate? }.not_to raise_error
    end
  end

  describe 'configuration assignment', :assignment do
    it 'allows setting allowed_commands to an array of strings' do
      new_commands = %w[ls pwd cat grep]
      config.allowed_commands = new_commands
      expect(config.allowed_commands).to eq(new_commands)
    end

    it 'allows setting command_timeout to positive integers' do
      config.command_timeout = 60
      expect(config.command_timeout).to eq(60)
    end

    it 'allows setting log_level to valid symbols' do
      %i[debug info warn error].each do |level|
        config.log_level = level
        expect(config.log_level).to eq(level)
      end
    end

    it 'allows toggling safe_mode between true and false' do
      config.safe_mode = false
      expect(config.safe_mode).to be false

      config.safe_mode = true
      expect(config.safe_mode).to be true
    end

    it 'allows setting max_results to positive integers' do
      config.max_results = 200
      expect(config.max_results).to eq(200)
    end

    it 'allows empty arrays for allowed_commands' do
      config.allowed_commands = []
      expect(config.allowed_commands).to eq([])
      expect(config.allowed_commands).to be_empty
    end

    it 'rejects zero values for command_timeout' do
      config.command_timeout = 0
      expect { config.validate? }.to raise_error(ArgumentError, /command_timeout must be positive/)
    end

    it 'rejects zero values for max_results' do
      config.max_results = 0
      expect { config.validate? }.to raise_error(ArgumentError, /max_results must be positive/)
    end

    it 'rejects invalid symbols for log_level' do
      config.log_level = :invalid_level
      expect { config.validate? }.to raise_error(ArgumentError, /log_level must be one of/)
    end
  end

  describe 'environment configuration', :environment do
    describe '#production_mode!' do
      it 'sets production environment settings (strict mode)' do
        config.production_mode!

        expect(config.safe_mode).to be true
        expect(config.log_level).to eq(:warn)
        expect(config.command_timeout).to eq(15)
        expect(config.max_results).to eq(50)
        expect(config.log_executions).to be true
      end
    end

    describe '#development_mode!' do
      it 'sets development environment settings (permissive mode)' do
        config.development_mode!

        expect(config.safe_mode).to be false
        expect(config.log_level).to eq(:debug)
        expect(config.command_timeout).to eq(60)
        expect(config.max_results).to eq(200)
        expect(config.log_executions).to be false
      end
    end

    describe '#test_mode!' do
      it 'sets test environment settings (balanced mode)' do
        config.test_mode!

        expect(config.safe_mode).to be true
        expect(config.log_level).to eq(:error)
        expect(config.command_timeout).to eq(30)
        expect(config.log_executions).to be false
      end
    end

    it 'initializes with correct default values' do
      expect(config.safe_mode).to be true
      expect(config.log_level).to eq(:info)
      expect(config.command_timeout).to eq(30)
      expect(config.max_results).to eq(100)
      expect(config.log_executions).to be false
    end

    it 'applies production mode settings correctly' do
      config.production_mode!

      expect(config.safe_mode).to be true
      expect(config.log_level).to eq(:warn)
      expect(config.command_timeout).to eq(15)
      expect(config.max_results).to eq(50)
      expect(config.log_executions).to be true
    end

    it 'applies development mode settings correctly' do
      config.development_mode!

      expect(config.safe_mode).to be false
      expect(config.log_level).to eq(:debug)
      expect(config.command_timeout).to eq(60)
      expect(config.max_results).to eq(200)
      expect(config.log_executions).to be false
    end

    it 'properly overrides settings when switching modes' do
      # Start in development
      config.development_mode!
      expect(config.safe_mode).to be false

      # Switch to production
      config.production_mode!
      expect(config.safe_mode).to be true
      expect(config.log_level).to eq(:warn)
    end

    it 'development mode changes safe_mode from default' do
      expect { config.development_mode! }
        .to change(config, :safe_mode).from(true).to(false)
    end

    it 'production mode changes command_timeout from default' do
      expect { config.production_mode! }
        .to change(config, :command_timeout).from(30).to(15)
    end

    it 'configuration remains valid after applying production mode presets' do
      config.production_mode!
      expect(config.valid?).to be true
      expect { config.validate? }.not_to raise_error
    end
  end

  it 'does not retain previous mode settings' do
    config.development_mode!
    original_timeout = config.command_timeout

    config.production_mode!

    expect(config.command_timeout).not_to eq(original_timeout)
    expect(config.command_timeout).to eq(15)
  end

  it 'configuration remains valid after applying development mode preset' do
    config.development_mode!
    expect(config.valid?).to be true
    expect { config.validate? }.not_to raise_error
  end

  it 'configuration remains valid after applying test mode preset' do
    config.test_mode!
    expect(config.valid?).to be true
    expect { config.validate? }.not_to raise_error
  end

  describe 'SDK integration', :sdk do
    describe 'SDK-required attributes' do
      it 'provides safe_mode for safety checks' do
        expect(config).to respond_to(:safe_mode)
        expect(config).to respond_to(:safe_mode=)
        expect(config.safe_mode).to be_in([true, false])
      end

      it 'provides command_timeout for execution limits' do
        expect(config).to respond_to(:command_timeout)
        expect(config).to respond_to(:command_timeout=)
        expect(config.command_timeout).to be_a(Numeric)
        expect(config.command_timeout).to be > 0
      end

      it 'provides max_results for query limits' do
        expect(config).to respond_to(:max_results)
        expect(config).to respond_to(:max_results=)
        expect(config.max_results).to be_a(Numeric)
        expect(config.max_results).to be > 0
      end

      it 'provides allowed_commands for command filtering' do
        expect(config).to respond_to(:allowed_commands)
        expect(config).to respond_to(:allowed_commands=)
        expect(config.allowed_commands).to be_an(Array)
      end

      it 'provides allowed_models for model access control' do
        expect(config).to respond_to(:allowed_models)
        expect(config).to respond_to(:allowed_models=)
        expect(config.allowed_models).to be_an(Array)
      end

      it 'provides log_level for SDK logging' do
        expect(config).to respond_to(:log_level)
        expect(config).to respond_to(:log_level=)
        expect(config.log_level).to be_in(%i[debug info warn error])
      end

      it 'provides enable_logging for SDK integration' do
        expect(config).to respond_to(:enable_logging)
        expect(config).to respond_to(:enable_logging=)
        # Set logging to true and check
        config.enable_logging = true
        expect(config.enable_logging).to be true

        # Set logging to false and check
        config.enable_logging = false
        expect(config.enable_logging).to be false
      end
    end

    describe 'legacy server methods removal' do
      it 'does not respond to server_mode methods' do
        expect(config).not_to respond_to(:server_mode)
        expect(config).not_to respond_to(:server_mode=)
      end

      it 'does not respond to server host methods' do
        expect(config).not_to respond_to(:server_host)
        expect(config).not_to respond_to(:server_host=)
      end

      it 'does not respond to server port methods' do
        expect(config).not_to respond_to(:server_port)
        expect(config).not_to respond_to(:server_port=)
      end

      it 'does not respond to legacy mode methods' do
        expect(config).not_to respond_to(:stdio_mode!)
        expect(config).not_to respond_to(:http_mode!)
        expect(config).not_to respond_to(:server_mode_valid?)
      end
    end

    describe 'STDIO transport compatibility' do
      it 'supports STDIO as the default and only transport mode' do
        # The configuration should not have any HTTP server configuration
        # STDIO is the default mode for MCP SDK
        expect(config).not_to respond_to(:server_mode)

        # Configuration should be valid for STDIO transport
        expect(config.valid?).to be true
      end

      it 'does not support HTTP server configuration' do
        # HTTP server methods should not exist
        expect(config).not_to respond_to(:http_mode!)
        expect(config).not_to respond_to(:server_host)
        expect(config).not_to respond_to(:server_port)
      end
    end

    describe 'tool configuration compatibility' do
      it 'provides model_allowed? method for SDK tools when empty' do
        expect(config).to respond_to(:model_allowed?)

        # Test with empty allowed_models (should allow all)
        config.allowed_models = []
        expect(config.model_allowed?('User')).to be true
        expect(config.model_allowed?(:Post)).to be true
      end

      it 'provides model_allowed? methods for SDK tools when populated' do
        # Test with specific allowed models
        config.allowed_models = %w[User Post]
        expect(config.model_allowed?('User')).to be true
        expect(config.model_allowed?('Post')).to be true
        expect(config.model_allowed?('Comment')).to be false
      end

      it 'provides validation methods for SDK integration' do
        expect(config).to respond_to(:valid?)
        expect(config).to respond_to(:validate?)

        # Should validate successfully with default configuration
        expect(config.valid?).to be true
        expect { config.validate? }.not_to raise_error
      end

      it 'provides environment configuration methods for SDK deployment in production' do
        config.production_mode!
        expect(config.valid?).to be true
      end

      it 'provides environment configuration methods for SDK deployment in development' do
        config.development_mode!
        expect(config.valid?).to be true
      end

      it 'provides environment configuration methods for SDK deployment in test' do
        config.test_mode!
        expect(config.valid?).to be true
      end
    end

    describe 'SDK configuration validation' do
      it 'validates all SDK-required attributes are present and valid' do
        # All attributes required by SDK tools should be present
        required_attributes = %i[
          safe_mode command_timeout max_results allowed_commands
          allowed_models log_level enable_logging
        ]

        required_attributes.each do |attr|
          expect(config).to respond_to(attr), "Missing required SDK attribute: #{attr}"
          expect(config).to respond_to("#{attr}="), "Missing setter for SDK attribute: #{attr}"
        end

        # Configuration should be valid for SDK use
        expect(config.valid?).to be true
        expect { config.validate? }.not_to raise_error
      end

      it 'ensures no legacy server configuration conflicts with SDK' do
        # These legacy methods should not exist to avoid SDK conflicts
        legacy_methods = %i[
          server_mode server_mode= server_host server_host= server_port server_port=
          stdio_mode! http_mode! server_mode_valid?
        ]

        legacy_methods.each do |method|
          expect(config).not_to respond_to(method), "Legacy method #{method} should not exist for SDK compatibility"
        end
      end
    end
  end

  describe 'basic functionality' do
    it 'initializes with default values' do
      expect(config.safe_mode).to be true
      expect(config.command_timeout).to eq(30)
      expect(config.max_results).to eq(100)
    end

    it 'validates configuration' do
      expect(config.valid?).to be true
    end
  end
end
