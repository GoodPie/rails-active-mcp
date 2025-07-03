RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  # Configure FactoryBot to load factories from spec/factories
  config.before(:suite) do
    FactoryBot.find_definitions
  end
end
