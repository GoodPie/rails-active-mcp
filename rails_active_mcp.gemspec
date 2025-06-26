# frozen_string_literal: true

require_relative 'lib/rails_active_mcp/version'

Gem::Specification.new do |spec|
  spec.name = 'rails-active-mcp'
  spec.version = RailsActiveMcp::VERSION
  spec.authors = ['Brandyn Britton']
  spec.email = ['brandynbb96@gmail.com']

  spec.summary = 'Rails Console access via Model Context Protocol (MCP)'
  spec.description = 'Secure Rails console access for AI agents through Model Context Protocol with safety features and read-only modes'
  spec.homepage = 'https://github.com/goodpie/rails-active-mcp'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Dependencies
  spec.add_runtime_dependency 'concurrent-ruby', '~> 1.3.5'
  spec.add_runtime_dependency 'rails', '~> 7.0'

  spec.add_dependency 'json', '~> 2.0'
  spec.add_dependency 'rack', '~> 3.0'
  spec.add_dependency 'timeout', '~> 0.4'
  spec.add_dependency 'webrick', '~> 1.8'

  # Development dependencies - keep versions consistent with Gemfile
  spec.add_development_dependency 'factory_bot_rails', '~> 6.0'
  spec.add_development_dependency 'rspec', '~> 3.1'
  spec.add_development_dependency 'rspec-rails'
  spec.add_development_dependency 'rubocop', '~> 1.77'
  spec.add_development_dependency 'rubocop-rails', '~> 2.32'
  spec.add_development_dependency 'rubocop-rspec'
  spec.add_development_dependency 'sqlite3', '~> 2.7'
end
