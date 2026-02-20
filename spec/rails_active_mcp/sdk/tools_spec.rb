# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'MCP Tool Protocol Compliance' do
  let(:config) { RailsActiveMcp::Configuration.new }
  let(:executor) { instance_double(RailsActiveMcp::ConsoleExecutor) }
  let(:server_context) { { rails_env: 'test', config: config } }

  before do
    RailsActiveMcp.configure do |c|
      c.safe_mode = true
      c.command_timeout = 30
      c.enabled = true
    end
    allow(RailsActiveMcp::ConsoleExecutor).to receive(:new).and_return(executor)
  end

  # ── Shared examples ──────────────────────────────────────────────

  shared_examples 'a valid MCP tool response' do
    it 'returns an MCP::Tool::Response' do
      expect(response).to be_a(MCP::Tool::Response)
    end

    it 'serializes to a hash with content array' do
      h = response.to_h
      expect(h).to have_key(:content)
      expect(h[:content]).to be_an(Array)
    end

    it 'has text content items with string text' do
      item = response.to_h[:content].first
      expect(item).to include(type: 'text')
      expect(item[:text]).to be_a(String)
    end
  end

  shared_examples 'a successful MCP tool response' do
    it_behaves_like 'a valid MCP tool response'

    it 'is not an error' do
      expect(response.error?).to be false
      expect(response.to_h[:isError]).to be false
    end
  end

  shared_examples 'an error MCP tool response' do
    it_behaves_like 'a valid MCP tool response'

    it 'is an error' do
      expect(response.error?).to be true
      expect(response.to_h[:isError]).to be true
    end
  end

  # ── ConsoleExecuteTool ───────────────────────────────────────────

  describe RailsActiveMcp::Sdk::Tools::ConsoleExecuteTool do
    context 'when execution succeeds' do
      let(:response) do
        allow(executor).to receive(:execute).and_return(
          success: true,
          code: '1 + 1',
          return_value: 2,
          return_value_string: '2',
          output: '',
          execution_time: 0.001
        )
        described_class.call(code: '1 + 1', server_context: server_context)
      end

      it_behaves_like 'a successful MCP tool response'

      it 'includes code in response text' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('Code: 1 + 1')
      end

      it 'includes return value in response text' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('Result: 2')
      end

      it 'includes execution time in response text' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('Execution time:')
      end
    end

    context 'when execution produces output' do
      let(:response) do
        allow(executor).to receive(:execute).and_return(
          success: true,
          code: 'puts "hello"',
          return_value: nil,
          return_value_string: 'nil',
          output: 'hello',
          execution_time: 0.001
        )
        described_class.call(code: 'puts "hello"', server_context: server_context)
      end

      it_behaves_like 'a successful MCP tool response'

      it 'includes captured output in response text' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('Output: hello')
      end
    end

    context 'when code fails safety check' do
      let(:response) do
        allow(executor).to receive(:execute)
          .and_raise(RailsActiveMcp::SafetyError, 'blocked: delete_all')
        described_class.call(code: 'User.delete_all', server_context: server_context)
      end

      it_behaves_like 'an error MCP tool response'

      it 'includes safety error message' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('Safety check failed')
      end
    end

    context 'when execution times out' do
      let(:response) do
        allow(executor).to receive(:execute)
          .and_raise(RailsActiveMcp::TimeoutError, 'timed out after 30 seconds')
        described_class.call(code: 'sleep(999)', server_context: server_context)
      end

      it_behaves_like 'an error MCP tool response'

      it 'includes timeout message' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('timed out')
      end
    end

    context 'when execution raises a runtime error' do
      let(:response) do
        allow(executor).to receive(:execute).and_return(
          success: false,
          error: 'undefined method `foo`',
          error_class: 'NoMethodError'
        )
        described_class.call(code: 'foo', server_context: server_context)
      end

      it_behaves_like 'an error MCP tool response'

      it 'includes error class in response text' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('NoMethodError')
      end
    end

    context 'when an unexpected StandardError is raised' do
      let(:response) do
        allow(executor).to receive(:execute)
          .and_raise(StandardError, 'something broke')
        described_class.call(code: 'boom', server_context: server_context)
      end

      it_behaves_like 'an error MCP tool response'

      it 'includes error message' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('something broke')
      end
    end

    describe 'tool definition' do
      it 'has the expected name' do
        expect(described_class.name_value).to eq('console_execute_tool')
      end

      it 'has a description' do
        expect(described_class.description_value).to be_a(String)
        expect(described_class.description_value).not_to be_empty
      end

      it 'requires code in input schema' do
        schema = described_class.input_schema_value.to_h
        expect(schema[:required]).to include('code')
      end

      it 'defines code, safe_mode, timeout, capture_output properties' do
        props = described_class.input_schema_value.to_h[:properties]
        expect(props.keys).to contain_exactly(:code, :safe_mode, :timeout, :capture_output)
      end

      it 'is annotated as destructive' do
        expect(described_class.annotations_value.destructive_hint).to be true
      end

      it 'is annotated as not read-only' do
        expect(described_class.annotations_value.read_only_hint).to be false
      end

      it 'is annotated as not idempotent' do
        expect(described_class.annotations_value.idempotent_hint).to be false
      end
    end
  end

  # ── DryRunTool ───────────────────────────────────────────────────

  describe RailsActiveMcp::Sdk::Tools::DryRunTool do
    context 'when code is safe' do
      let(:response) do
        allow(executor).to receive(:dry_run).and_return(
          code: 'User.count',
          safety_analysis: { safe: true, read_only: true, summary: 'Safe read-only operation', violations: [] },
          estimated_risk: :low,
          recommendations: []
        )
        described_class.call(code: 'User.count', server_context: server_context)
      end

      it_behaves_like 'a successful MCP tool response'

      it 'reports safe=Yes' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('Safe: Yes')
      end

      it 'reports risk level' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('Risk level: low')
      end

      it 'does not include violations section' do
        text = response.to_h[:content].first[:text]
        expect(text).not_to include('Violations:')
      end
    end

    context 'when code is dangerous' do
      let(:response) do
        allow(executor).to receive(:dry_run).and_return(
          code: 'User.delete_all',
          safety_analysis: {
            safe: false,
            read_only: false,
            summary: 'Dangerous operation detected',
            violations: [
              { description: 'Mass deletion', severity: :critical }
            ]
          },
          estimated_risk: :critical,
          recommendations: ['Consider using read-only alternatives']
        )
        described_class.call(code: 'User.delete_all', server_context: server_context)
      end

      it_behaves_like 'a successful MCP tool response'

      it 'reports safe=No' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('Safe: No')
      end

      it 'lists violations with severity' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('Mass deletion (critical)')
      end

      it 'lists recommendations' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('Consider using read-only alternatives')
      end
    end

    describe 'tool definition' do
      it 'has the expected name' do
        expect(described_class.name_value).to eq('dry_run_tool')
      end

      it 'has a description' do
        expect(described_class.description_value).not_to be_empty
      end

      it 'requires code in input schema' do
        schema = described_class.input_schema_value.to_h
        expect(schema[:required]).to include('code')
      end

      it 'is annotated as read-only' do
        expect(described_class.annotations_value.read_only_hint).to be true
      end

      it 'is annotated as not destructive' do
        expect(described_class.annotations_value.destructive_hint).to be false
      end

      it 'is annotated as idempotent' do
        expect(described_class.annotations_value.idempotent_hint).to be true
      end
    end
  end

  # ── ModelInfoTool ────────────────────────────────────────────────

  describe RailsActiveMcp::Sdk::Tools::ModelInfoTool do
    context 'when model exists and is allowed' do
      let(:response) do
        allow(executor).to receive(:get_model_info).with('User').and_return(
          success: true,
          model_name: 'User',
          table_name: 'users',
          primary_key: 'id',
          columns: [
            { name: 'id', type: :integer, primary: true },
            { name: 'email', type: :string, primary: false }
          ],
          associations: [
            { name: :posts, type: :has_many, class_name: 'Post' }
          ],
          validators: []
        )
        described_class.call(model: 'User', server_context: server_context)
      end

      it_behaves_like 'a successful MCP tool response'

      it 'includes model name' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('Model: User')
      end

      it 'includes table name' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('Table: users')
      end

      it 'includes column info' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('email: string')
      end

      it 'includes associations' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('posts: has_many -> Post')
      end
    end

    context 'when model is disallowed' do
      let(:response) do
        allow(executor).to receive(:get_model_info).with('Secret').and_return(
          success: false,
          error: "Access to model 'Secret' is not allowed"
        )
        described_class.call(model: 'Secret', server_context: server_context)
      end

      it_behaves_like 'an error MCP tool response'

      it 'reports access denied' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('not allowed')
      end
    end

    context 'when model is not found' do
      let(:response) do
        allow(executor).to receive(:get_model_info).with('Nonexistent').and_return(
          success: false,
          error: "Model 'Nonexistent' not found: uninitialized constant Nonexistent"
        )
        described_class.call(model: 'Nonexistent', server_context: server_context)
      end

      it_behaves_like 'an error MCP tool response'

      it 'reports model not found' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('not found')
      end
    end

    describe 'tool definition' do
      it 'has the expected name' do
        expect(described_class.name_value).to eq('model_info_tool')
      end

      it 'requires model in input schema' do
        schema = described_class.input_schema_value.to_h
        expect(schema[:required]).to include('model')
      end

      it 'defines model, include_schema, include_associations, include_validations properties' do
        props = described_class.input_schema_value.to_h[:properties]
        expect(props.keys).to contain_exactly(:model, :include_schema, :include_associations, :include_validations)
      end

      it 'is annotated as read-only' do
        expect(described_class.annotations_value.read_only_hint).to be true
      end

      it 'is annotated as not destructive' do
        expect(described_class.annotations_value.destructive_hint).to be false
      end
    end
  end

  # ── SafeQueryTool ────────────────────────────────────────────────

  describe RailsActiveMcp::Sdk::Tools::SafeQueryTool do
    context 'when query succeeds' do
      let(:response) do
        allow(executor).to receive(:execute_safe_query).and_return(
          success: true,
          result: [{ id: 1, email: 'test@example.com' }],
          count: 1
        )
        described_class.call(model: 'User', method: 'where', server_context: server_context,
                             args: [{ active: true }])
      end

      it_behaves_like 'a successful MCP tool response'

      it 'includes query description' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('Query: User.where')
      end

      it 'includes count' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('Count: 1')
      end

      it 'includes result' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('Result:')
      end
    end

    context 'when method is disallowed' do
      let(:response) do
        allow(executor).to receive(:execute_safe_query).and_return(
          success: false,
          error: "Method 'delete_all' is not allowed for safe queries"
        )
        described_class.call(model: 'User', method: 'delete_all', server_context: server_context)
      end

      it_behaves_like 'an error MCP tool response'

      it 'reports method not allowed' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('not allowed')
      end
    end

    context 'when model is disallowed' do
      let(:response) do
        allow(executor).to receive(:execute_safe_query).and_return(
          success: false,
          error: "Access to model 'Secret' is not allowed"
        )
        described_class.call(model: 'Secret', method: 'count', server_context: server_context)
      end

      it_behaves_like 'an error MCP tool response'

      it 'reports model not allowed' do
        text = response.to_h[:content].first[:text]
        expect(text).to include('not allowed')
      end
    end

    describe 'tool definition' do
      it 'has the expected name' do
        expect(described_class.name_value).to eq('safe_query_tool')
      end

      it 'requires model and method in input schema' do
        schema = described_class.input_schema_value.to_h
        expect(schema[:required]).to contain_exactly('model', 'method')
      end

      it 'defines model, method, args, limit properties' do
        props = described_class.input_schema_value.to_h[:properties]
        expect(props.keys).to contain_exactly(:model, :method, :args, :limit)
      end

      it 'is annotated as read-only' do
        expect(described_class.annotations_value.read_only_hint).to be true
      end

      it 'is annotated as not destructive' do
        expect(described_class.annotations_value.destructive_hint).to be false
      end

      it 'is annotated as idempotent' do
        expect(described_class.annotations_value.idempotent_hint).to be true
      end
    end
  end

  # ── Cross-tool validation ────────────────────────────────────────

  describe 'All MCP tools' do
    let(:all_tools) do
      [
        RailsActiveMcp::Sdk::Tools::ConsoleExecuteTool,
        RailsActiveMcp::Sdk::Tools::DryRunTool,
        RailsActiveMcp::Sdk::Tools::ModelInfoTool,
        RailsActiveMcp::Sdk::Tools::SafeQueryTool
      ]
    end

    let(:read_only_tools) do
      [
        RailsActiveMcp::Sdk::Tools::DryRunTool,
        RailsActiveMcp::Sdk::Tools::ModelInfoTool,
        RailsActiveMcp::Sdk::Tools::SafeQueryTool
      ]
    end

    it 'all respond to .call, .description_value, and .name_value' do
      expect(all_tools).to all(respond_to(:call).and(respond_to(:description_value)).and(respond_to(:name_value)))
    end

    it 'all have non-empty string descriptions' do
      descriptions = all_tools.map(&:description_value)
      expect(descriptions).to all(be_a(String).and(satisfy('be non-empty', &:present?)))
    end

    it 'all have non-empty string names' do
      names = all_tools.map(&:name_value)
      expect(names).to all(be_a(String).and(satisfy('be non-empty', &:present?)))
    end

    it 'all have input schemas with properties and required fields' do
      all_tools.each do |tool|
        schema = tool.input_schema_value.to_h
        expect(schema[:properties]).not_to be_empty, "#{tool.name_value} has no schema properties"
        expect(schema[:required]).not_to be_empty, "#{tool.name_value} has no required fields"
      end
    end

    it 'all have annotations' do
      annotations = all_tools.map(&:annotations_value)
      expect(annotations).to all(be_a(MCP::Tool::Annotations))
    end

    it 'read-only tools all have read_only_hint: true' do
      hints = read_only_tools.map { |t| t.annotations_value.read_only_hint }
      expect(hints).to all(be true)
    end

    it 'only ConsoleExecuteTool has destructive_hint: true' do
      destructive_map = all_tools.to_h { |t| [t.name_value, t.annotations_value.destructive_hint] }
      expect(destructive_map['console_execute_tool']).to be true
      expect(destructive_map.values.count(true)).to eq(1)
    end

    it 'all serialize to valid MCP tool definitions via to_h' do
      all_tools.each do |tool|
        h = tool.to_h
        expect(h.keys).to include(:name, :description, :inputSchema, :annotations)
      end
    end
  end
end
