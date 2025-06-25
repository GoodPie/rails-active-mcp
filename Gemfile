source "https://rubygems.org"

# Specify your gem's dependencies in rails-active-mcp.gemspec
gemspec

gem "rails", ">= 7.0"

group :development, :test do
  gem "rspec", "~> 3.1"
  gem "rspec-rails"
  gem "factory_bot_rails", "~> 6.0"
  gem "sqlite3", "~> 2.7"
  gem "byebug"
end

group :development do
  gem "rubocop", "~> 1.77"
  gem "rubocop-rails", "~> 2.32"
  gem "rubocop-rspec"
  gem "yard"
  gem "redcarpet"  # For YARD markdown support
end

# For testing the gem in a Rails app
gem "sprockets-rails"  # Required for Rails 7+
