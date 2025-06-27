# frozen_string_literal: true

module RailsActiveMcp
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      desc 'Install Rails Active MCP'

      def create_initializer
        template 'initializer.rb', 'config/initializers/rails_active_mcp.rb'
      end

      def create_binstub
        # Create binstub for easy server execution
        create_file 'bin/rails-active-mcp-server', <<~RUBY
          #!/usr/bin/env ruby

          # Binstub for Rails Active MCP Server
          # This ensures the server runs within the Rails project context

          require 'bundler/setup'
          require 'stringio'

          # Set Rails environment
          ENV['RAILS_ENV'] ||= 'development'

          # Suppress Rails loading output for MCP JSON protocol
          unless ENV['RAILS_MCP_DEBUG'] == '1'
            original_stdout = $stdout
            original_stderr = $stderr
            $stdout = StringIO.new
            $stderr = StringIO.new
          end

          # Load Rails application
          require_relative '../config/environment'

          # Restore output streams
          unless ENV['RAILS_MCP_DEBUG'] == '1'
            $stdout = original_stdout
            $stderr = original_stderr
          end

          # Now run the actual MCP server
          load Gem.bin_path('rails_active_mcp', 'rails-active-mcp-server')
        RUBY

        chmod 'bin/rails-active-mcp-server', 0o755
        say 'Created Rails binstub at bin/rails-active-mcp-server', :green
      end

      def create_mcp_route
        # Check if routes file exists and is writable
        routes_file = 'config/routes.rb'
        return unless File.exist?(routes_file)

        # Read current routes to check for conflicts
        routes_content = File.read(routes_file)

        if routes_content.include?('/mcp')
          say "Warning: Route '/mcp' already exists. Skipping route creation.", :yellow
          say "Manual setup: Add 'mount RailsActiveMcp::Engine, at: \"/mcp\"' to your routes.rb", :yellow
        else
          # Use Engine mounting instead of direct server mounting
          route "mount RailsActiveMcp::Engine, at: '/mcp'"
          say "Added MCP route at '/mcp'. You can change this in config/routes.rb", :green
        end
      end

      def create_mcp_config
        template 'mcp.ru', 'mcp.ru'
      end

      def show_readme
        readme 'README.md' if behavior == :invoke
      end

      def show_post_install_instructions
        return unless behavior == :invoke

        say "\n" + '=' * 50, :green
        say 'Rails Active MCP Installation Complete!', :green
        say '=' * 50, :green
        say "\nNext steps:", :green
        say '1. Configure the gem in config/initializers/rails_active_mcp.rb', :yellow
        say '2. For Claude Desktop, use: bin/rails-active-mcp-server stdio', :yellow
        say '3. For HTTP mode, use: bin/rails-active-mcp-server http', :yellow
        say '4. Alternative: bundle exec rails-active-mcp-server stdio', :yellow
        say "\nTroubleshooting:", :green
        say '- Set RAILS_MCP_DEBUG=1 for verbose logging', :yellow
        say '- Check log/rails_mcp_stderr.log for errors', :yellow
        say '=' * 50, :green
      end

      private

      def readme(path)
        readme_path = File.join(self.class.source_root, path)
        if File.exist?(readme_path)
          say IO.read(readme_path), :green
        else
          say "README file not found at #{readme_path}", :green
        end
      rescue StandardError => e
        say "Error reading README: #{e.message}", :red
      end
    end
  end
end
