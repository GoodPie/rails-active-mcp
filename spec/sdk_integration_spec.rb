# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SDK Integration' do
  describe 'Server startup' do
    it 'can create SDK server without errors' do
      expect { require_relative '../lib/rails_active_mcp/sdk/server' }.not_to raise_error
      expect { RailsActiveMcp::Sdk::Server.new }.not_to raise_error
    end
  end

  describe 'Tool loading' do
    before do
      require_relative '../lib/rails_active_mcp/sdk/server'
    end

    it 'loads all SDK tools without errors' do
      server = RailsActiveMcp::Sdk::Server.new

      # Check that tools are loaded
      expect(server.mcp_server).to be_a(MCP::Server)

      # Verify tools can be instantiated
      expect { RailsActiveMcp::Sdk::Tools::ConsoleExecuteTool.new }.not_to raise_error
      expect { RailsActiveMcp::Sdk::Tools::ModelInfoTool.new }.not_to raise_error
      expect { RailsActiveMcp::Sdk::Tools::SafeQueryTool.new }.not_to raise_error
      expect { RailsActiveMcp::Sdk::Tools::DryRunTool.new }.not_to raise_error
    end
  end

  describe 'Configuration' do
    it 'has valid default configuration' do
      config = RailsActiveMcp.config
      expect(config).to be_valid
      expect(config.allowed_commands).to be_an(Array)
      expect(config.command_timeout).to be > 0
      expect(config.enable_logging).to be_in([true, false])
      expect(config.log_level).to be_a(Symbol)
    end
  end
end
