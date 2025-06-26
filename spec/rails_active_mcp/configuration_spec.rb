# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsActiveMcp::Configuration do
  let(:config) { described_class.new }

  describe 'initialization' do
    it 'sets default server mode to stdio' do
      expect(config.server_mode).to eq(:stdio)
    end

    it 'sets default server host to localhost' do
      expect(config.server_host).to eq('localhost')
    end

    it 'sets default server port to 3001' do
      expect(config.server_port).to eq(3001)
    end
  end

  describe 'server mode configuration' do
    describe '#stdio_mode!' do
      it 'sets server mode to stdio' do
        config.stdio_mode!
        expect(config.server_mode).to eq(:stdio)
      end
    end

    describe '#http_mode!' do
      it 'sets server mode to http with default host and port' do
        config.http_mode!
        expect(config.server_mode).to eq(:http)
        expect(config.server_host).to eq('localhost')
        expect(config.server_port).to eq(3001)
      end

      it 'accepts custom host and port' do
        config.http_mode!(host: '0.0.0.0', port: 8080)
        expect(config.server_mode).to eq(:http)
        expect(config.server_host).to eq('0.0.0.0')
        expect(config.server_port).to eq(8080)
      end
    end

    describe '#server_mode_valid?' do
      it 'returns true for stdio mode' do
        config.server_mode = :stdio
        expect(config.server_mode_valid?).to be true
      end

      it 'returns true for http mode' do
        config.server_mode = :http
        expect(config.server_mode_valid?).to be true
      end

      it 'returns false for invalid mode' do
        config.server_mode = :invalid
        expect(config.server_mode_valid?).to be false
      end
    end
  end

  describe 'validation' do
    it 'validates server mode' do
      config.server_mode = :invalid
      expect { config.validate! }.to raise_error(ArgumentError, /invalid server_mode/)
    end

    it 'validates server port is positive' do
      config.server_port = 0
      expect { config.validate! }.to raise_error(ArgumentError, /server_port must be positive/)
    end

    it 'validates server port is not negative' do
      config.server_port = -1
      expect { config.validate! }.to raise_error(ArgumentError, /server_port must be positive/)
    end

    it 'passes validation with valid configuration' do
      config.server_mode = :stdio
      config.server_port = 3001
      expect { config.validate! }.not_to raise_error
    end
  end

  describe 'existing functionality' do
    it 'still validates timeout' do
      config.default_timeout = 0
      expect { config.validate! }.to raise_error(ArgumentError, /timeout must be positive/)
    end

    it 'still validates max_results' do
      config.max_results = 0
      expect { config.validate! }.to raise_error(ArgumentError, /max_results must be positive/)
    end
  end
end
