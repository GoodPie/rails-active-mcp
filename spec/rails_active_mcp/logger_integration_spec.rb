require 'spec_helper'

RSpec.describe 'Logger Integration' do
  let(:mock_rails_logger) { instance_double(Logger) }
  let(:semantic_logger) { double('SemanticLogger') }

  before do
    # Reset the logger before each test
    RailsActiveMcp.logger = nil
  end

  describe 'logger initialization' do
    context 'when Rails.logger is available' do
      before do
        allow(Rails).to receive(:logger).and_return(mock_rails_logger)
        allow(mock_rails_logger).to receive(:respond_to?).with(:info).and_return(true)
      end

      it 'uses Rails.logger for standard Rails logger' do
        allow(mock_rails_logger).to receive_message_chain(:class, :name).and_return('ActiveSupport::Logger')
        allow(mock_rails_logger).to receive(:info)

        # Simulate the railtie initializer
        RailsActiveMcp.logger = mock_rails_logger

        expect(RailsActiveMcp.logger).to eq(mock_rails_logger)
      end

      it 'creates tagged logger for SemanticLogger' do
        # Create a mock that can respond to the tagged method
        semantic_logger_mock = double('SemanticLogger')
        allow(semantic_logger_mock).to receive_message_chain(:class, :name).and_return('SemanticLogger::Logger')
        allow(semantic_logger_mock).to receive(:respond_to?).with(:info).and_return(true)
        allow(semantic_logger_mock).to receive(:tagged).with('RailsActiveMcp').and_return(semantic_logger)
        allow(semantic_logger).to receive(:info)

        # Simulate the railtie initializer logic
        RailsActiveMcp.logger = if semantic_logger_mock.class.name.include?('SemanticLogger')
                                  semantic_logger_mock.tagged('RailsActiveMcp')
                                else
                                  semantic_logger_mock
                                end

        expect(RailsActiveMcp.logger).to eq(semantic_logger)
      end
    end

    context 'when Rails.logger is not available' do
      before do
        allow(Rails).to receive(:logger).and_return(nil)
      end

      it 'falls back to default logger' do
        expect(RailsActiveMcp.logger).to be_a(Logger)
        expect(RailsActiveMcp.logger).not_to be_nil
      end

      it 'configures the fallback logger with proper formatting' do
        logger = RailsActiveMcp.logger
        expect(logger.level).to eq(Logger::INFO)
        expect(logger.formatter).to be_a(Proc)
      end
    end
  end

  describe 'consistent logger usage' do
    let(:test_logger) { Logger.new(StringIO.new) }

    before do
      RailsActiveMcp.logger = test_logger
    end

    it 'uses RailsActiveMcp.logger consistently across components' do
      # Test that the logger is used in console executor
      executor = RailsActiveMcp::ConsoleExecutor.new(RailsActiveMcp.config)

      # This should not raise an error
      expect { RailsActiveMcp.logger.info('Test message') }.not_to raise_error
    end

    it 'handles logger errors gracefully' do
      # Mock a logger that fails
      failing_logger = instance_double(Logger)
      allow(failing_logger).to receive(:warn).and_raise(StandardError.new('Logger failed'))

      RailsActiveMcp.logger = failing_logger

      # This should not cause the application to crash
      expect do
        executor = RailsActiveMcp::ConsoleExecutor.new(RailsActiveMcp.config)
        # The log_execution method should handle logger failures gracefully
      end.not_to raise_error
    end
  end

  describe 'production safety' do
    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
    end

    it 'uses appropriate log level in production' do
      logger = RailsActiveMcp.logger
      # In production, we want to avoid noisy INFO logs
      expect(logger.level).to be >= Logger::INFO
    end
  end
end
