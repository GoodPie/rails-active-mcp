# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in rails-active-mcp.gemspec
gemspec

gem 'rails', '>= 7.0'

group :development, :test do
  gem 'byebug'
  gem 'database_cleaner-active_record', '~> 2.1'
  gem 'simplecov', '~> 0.22'
  gem 'timecop', '~> 0.9.8'
  gem 'webmock', '~> 3.19'
end

group :development do
  gem 'redcarpet' # For YARD markdown support
  gem 'yard'
end

# For testing the gem in a Rails app
gem 'sprockets-rails' # Required for Rails 7+

# Official MCP Ruby SDK (MCP 2025-11-25 spec)
gem 'mcp', '~> 0.7.0'
