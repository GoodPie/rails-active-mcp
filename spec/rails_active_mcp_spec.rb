# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsActiveMcp do
  describe '.configure' do
    it 'yields configuration object' do
      expect { |b| described_class.configure(&b) }.to yield_with_args(kind_of(RailsActiveMcp::Configuration))
    end

    it 'stores configuration' do
      described_class.configure do |config|
        config.enabled = false
      end

      expect(described_class.config.enabled).to be false
    end
  end

  describe '.safe?' do
    before do
      described_class.configure do |config|
        config.safe_mode = true
      end
    end

    it 'returns true for safe code' do
      expect(described_class.safe?('User.count')).to be true
    end

    it 'returns false for dangerous code' do
      expect(described_class.safe?('User.delete_all')).to be false
    end
  end

  describe '.execute' do
    before do
      described_class.configure do |config|
        config.safe_mode = false # Allow execution for testing
      end
    end

    it 'executes simple code' do
      result = described_class.execute('1 + 1')

      expect(result[:success]).to be true
      expect(result[:return_value]).to eq 2
    end

    it 'captures output' do
      result = described_class.execute('puts "hello"')

      expect(result[:success]).to be true
      expect(result[:output]).to include 'hello'
    end

    it 'handles errors gracefully' do
      result = described_class.execute('undefined_method')

      expect(result[:success]).to be false
      expect(result[:error]).to be_present
    end
  end
end
