require 'spec_helper'

RSpec.describe RailsActiveMcp::SafetyChecker do
  let(:config) { RailsActiveMcp::Configuration.new }
  let(:checker) { described_class.new(config) }

  describe '#safe?' do
    context 'when safe_mode is enabled' do
      before { config.safe_mode = true }

      it 'allows safe operations' do
        expect(checker.safe?('User.count')).to be true
        expect(checker.safe?('User.find(1)')).to be true
        expect(checker.safe?('User.where(active: true)')).to be true
      end

      it 'blocks dangerous operations' do
        expect(checker.safe?('User.delete_all')).to be false
        expect(checker.safe?('system("rm -rf /")')).to be false
        expect(checker.safe?('eval("dangerous code")')).to be false
      end
    end

    context 'when safe_mode is disabled' do
      before { config.safe_mode = false }

      it 'allows most operations' do
        expect(checker.safe?('User.count')).to be true
        expect(checker.safe?('User.delete_all')).to be true # Still dangerous but allowed
      end

      it 'still blocks critical operations' do
        expect(checker.safe?('system("rm -rf /")')).to be false
        expect(checker.safe?('exec("dangerous")')).to be false
      end
    end
  end

  describe '#analyze' do
    it 'provides detailed analysis' do
      analysis = checker.analyze('User.delete_all')

      expect(analysis).to include(:safe, :read_only, :violations, :summary)
      expect(analysis[:violations]).not_to be_empty
      expect(analysis[:violations].first).to include(:pattern, :description, :severity)
    end
  end

  describe '#read_only?' do
    it 'identifies read-only operations' do
      expect(checker.read_only?('User.count')).to be true
      expect(checker.read_only?('User.find(1)')).to be true
      expect(checker.read_only?('User.where(active: true).pluck(:email)')).to be true
    end

    it 'identifies mutation operations' do
      expect(checker.read_only?('User.create(name: "test")')).to be false
      expect(checker.read_only?('user.update(name: "new")')).to be false
      expect(checker.read_only?('User.delete_all')).to be false
    end
  end
end
