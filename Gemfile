source "https://rubygems.org"

# Specify your gem's dependencies in rails-active-mcp.gemspec
gemspec

gem "rails", ">= 6.0"
gem "actionmcp", "~> 0.50"

group :development, :test do
  gem "rspec", "~> 3.0"
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "sqlite3", "~> 1.4"
  gem "byebug"
end

group :development do
  gem "rubocop", "~> 1.21"
  gem "rubocop-rails", "~> 2.0"
  gem "rubocop-rspec"
  gem "yard"
  gem "redcarpet"  # For YARD markdown support
end

# For testing the gem in a Rails app
gem "sprockets-rails"  # Required for Rails 7+