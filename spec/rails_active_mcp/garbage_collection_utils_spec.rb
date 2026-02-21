# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsActiveMcp::GarbageCollectionUtils do
  describe '.probalistic_clean!' do
    context 'when ActiveRecord is not defined' do
      before do
        hide_const('ActiveRecord::Base')
      end

      it 'returns early without error' do
        expect { described_class.probalistic_clean! }.not_to raise_error
      end

      it 'does not trigger GC' do
        expect(GC).not_to receive(:start)
        described_class.probalistic_clean!
      end
    end

    context 'with Rails 7.2+ (release_connection available)' do
      let(:mock_pool) { double('ConnectionPool') }

      before do
        stub_const('::ActiveRecord::Base', double('ActiveRecord'))
        allow(ActiveRecord::Base).to receive(:connection_pool).and_return(mock_pool)
        allow(mock_pool).to receive(:respond_to?).with(:release_connection).and_return(true)
        allow(mock_pool).to receive(:release_connection)
        allow(described_class).to receive(:rand).with(100).and_return(99)
      end

      it 'calls connection_pool.release_connection' do
        expect(mock_pool).to receive(:release_connection)
        described_class.probalistic_clean!
      end

      it 'does not call clear_active_connections!' do
        expect(ActiveRecord::Base).not_to receive(:clear_active_connections!)
        described_class.probalistic_clean!
      end
    end

    context 'with older Rails (clear_active_connections! available)' do
      let(:mock_pool) { double('ConnectionPool') }

      before do
        stub_const('::ActiveRecord::Base', double('ActiveRecord'))
        allow(ActiveRecord::Base).to receive(:connection_pool).and_return(mock_pool)
        allow(mock_pool).to receive(:respond_to?).with(:release_connection).and_return(false)
        allow(ActiveRecord::Base).to receive(:respond_to?).with(:clear_active_connections!).and_return(true)
        allow(ActiveRecord::Base).to receive(:clear_active_connections!)
        allow(described_class).to receive(:rand).with(100).and_return(99)
      end

      it 'calls clear_active_connections!' do
        expect(ActiveRecord::Base).to receive(:clear_active_connections!)
        described_class.probalistic_clean!
      end
    end

    context 'when neither cleanup method is available' do
      let(:mock_pool) { double('ConnectionPool') }

      before do
        stub_const('::ActiveRecord::Base', double('ActiveRecord'))
        allow(ActiveRecord::Base).to receive(:connection_pool).and_return(mock_pool)
        allow(mock_pool).to receive(:respond_to?).with(:release_connection).and_return(false)
        allow(ActiveRecord::Base).to receive(:respond_to?).with(:clear_active_connections!).and_return(false)
        allow(described_class).to receive(:rand).with(100).and_return(99)
      end

      it 'does not raise an error' do
        expect { described_class.probalistic_clean! }.not_to raise_error
      end
    end

    context 'with probabilistic GC' do
      let(:mock_pool) { double('ConnectionPool') }

      before do
        stub_const('::ActiveRecord::Base', double('ActiveRecord'))
        allow(ActiveRecord::Base).to receive(:connection_pool).and_return(mock_pool)
        allow(mock_pool).to receive(:respond_to?).with(:release_connection).and_return(true)
        allow(mock_pool).to receive(:release_connection)
      end

      it 'triggers GC when rand returns a value below 5' do
        allow(described_class).to receive(:rand).with(100).and_return(3)
        expect(GC).to receive(:start)
        described_class.probalistic_clean!
      end

      it 'does not trigger GC when rand returns a value of 5 or above' do
        allow(described_class).to receive(:rand).with(100).and_return(5)
        expect(GC).not_to receive(:start)
        described_class.probalistic_clean!
      end
    end
  end
end
