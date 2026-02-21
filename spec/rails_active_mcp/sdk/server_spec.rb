# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsActiveMcp::Sdk::Server do
  let(:server) { described_class.new }
  let(:mcp_server) { server.mcp_server }

  around do |example|
    original = ENV.fetch('RAILS_MCP_DEBUG', nil)
    ENV['RAILS_MCP_DEBUG'] = '1'
    example.run
  ensure
    if original
      ENV['RAILS_MCP_DEBUG'] = original
    else
      ENV.delete('RAILS_MCP_DEBUG')
    end
  end

  def jsonrpc_request(method, params = {}, id: 1)
    { jsonrpc: '2.0', id: id, method: method, params: params }
  end

  describe 'server initialization' do
    it 'creates without error' do
      expect { described_class.new }.not_to raise_error
    end

    it 'exposes an MCP::Server instance' do
      expect(mcp_server).to be_a(MCP::Server)
    end
  end

  describe 'tool registration' do
    let(:expected_tools) do
      [
        RailsActiveMcp::Sdk::Tools::ConsoleExecuteTool,
        RailsActiveMcp::Sdk::Tools::ModelInfoTool,
        RailsActiveMcp::Sdk::Tools::SafeQueryTool,
        RailsActiveMcp::Sdk::Tools::DryRunTool
      ]
    end

    it 'registers all 4 tools' do
      expect(mcp_server.tools.size).to eq(4)
    end

    it 'registers tools with correct names' do
      registered_names = mcp_server.tools.keys
      expected_names = expected_tools.map(&:name_value)

      expect(registered_names).to match_array(expected_names)
    end

    it 'maps each name to the correct tool class' do
      expected_tools.each do |tool_class|
        expect(mcp_server.tools[tool_class.name_value]).to eq(tool_class)
      end
    end
  end

  describe 'server context' do
    let(:context) { mcp_server.server_context }

    it 'contains rails_env' do
      expect(context).to have_key(:rails_env)
    end

    it 'contains rails_root' do
      expect(context).to have_key(:rails_root)
    end

    it 'contains config as a Configuration instance' do
      expect(context[:config]).to be_a(RailsActiveMcp::Configuration)
    end

    it 'contains gem_version' do
      expect(context[:gem_version]).to eq(RailsActiveMcp::VERSION)
    end
  end

  describe 'tools/list dispatch' do
    let(:result) do
      mcp_server.handle(jsonrpc_request('tools/list'))
    end

    it 'returns a JSON-RPC success response' do
      expect(result).to have_key(:jsonrpc)
      expect(result[:jsonrpc]).to eq('2.0')
      expect(result).to have_key(:result)
    end

    it 'returns a tools array with all 4 tools' do
      tools = result[:result][:tools]
      expect(tools).to be_an(Array)
      expect(tools.size).to eq(4)
    end

    it 'each tool has name, description, inputSchema, and annotations' do
      keys = result[:result][:tools].map(&:keys)
      expect(keys).to all(include(:name, :description, :inputSchema, :annotations))
    end
  end

  describe 'tools/call dispatch' do
    let(:executor) { instance_double(RailsActiveMcp::ConsoleExecutor) }

    before do
      allow(RailsActiveMcp::ConsoleExecutor).to receive(:new).and_return(executor)
    end

    it 'executes console_execute_tool and returns content' do
      allow(executor).to receive(:execute).and_return(
        success: true, code: '1 + 1', return_value: 2,
        return_value_string: '2', output: '', execution_time: 0.001
      )

      result = mcp_server.handle(
        jsonrpc_request('tools/call', { name: 'console_execute_tool', arguments: { code: '1 + 1' } })
      )

      expect(result[:result]).to include(isError: false)
      expect(result[:result][:content].first[:text]).to include('Result: 2')
    end

    it 'executes dry_run_tool and returns safety analysis' do
      allow(executor).to receive(:dry_run).and_return(
        code: 'User.delete_all',
        safety_analysis: {
          safe: false, read_only: false, summary: 'Dangerous operation',
          violations: [{ description: 'Mass deletion', severity: :critical }]
        },
        estimated_risk: :critical,
        recommendations: ['Do not execute']
      )

      result = mcp_server.handle(
        jsonrpc_request('tools/call', { name: 'dry_run_tool', arguments: { code: 'User.delete_all' } })
      )

      text = result[:result][:content].first[:text]
      expect(text).to include('Safe: No')
      expect(text).to include('Mass deletion (critical)')
    end

    it 'returns error for a non-existent tool' do
      result = mcp_server.handle(
        jsonrpc_request('tools/call', { name: 'nonexistent_tool', arguments: {} })
      )

      # MCP SDK 0.7.0 returns a tool error response (result with isError: true)
      # MCP SDK 0.7.1+ returns a JSON-RPC error response (error key)
      if result[:result]
        expect(result[:result][:isError]).to be true
        expect(result[:result][:content].first[:text]).to include('Tool not found')
      else
        expect(result[:error]).to be_a(Hash)
        expect(result[:error][:data]).to include('Tool not found')
      end
    end
  end
end
