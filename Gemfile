# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in rails-active-mcp.gemspec
gemspec

gem 'rails', '>= 7.0'

group :development, :test do
  gem 'byebug'
  gem 'database_cleaner-active_record', '~> 2.1'
  gem 'factory_bot_rails', '~> 6.0'
  gem 'rspec', '~> 3.1'
  gem 'rspec-rails'
  gem 'sqlite3', '~> 2.7'
  gem 'timecop', '~> 0.9.8'
  gem 'webmock', '~> 3.19'
end

group :development do
  gem 'redcarpet' # For YARD markdown support
  gem 'rubocop', '~> 1.77'
  gem 'rubocop-rails', '~> 2.32'
  gem 'rubocop-rspec'
  gem 'yard'
end

group :development, :test do
  gem 'simplecov', '~> 0.22'
# For testing the gem in a Rails app
gem 'sprockets-rails' # Required for Rails 7+

# Official MCP Ruby SDK for migration
gem 'mcp', '~> 0.1.0'
