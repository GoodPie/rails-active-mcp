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

          # Set Rails environment
          ENV['RAILS_ENV'] ||= 'development'

          # Load Rails application first
          require_relative '../config/environment'

          # Now start the MCP server using the SDK implementation
          require 'rails_active_mcp/sdk/server'

          begin
            server = RailsActiveMcp::SDK::Server.new
            server.run
          rescue StandardError => e
            warn "Error starting Rails Active MCP server: \#{e.message}"
            warn e.backtrace if ENV['RAILS_MCP_DEBUG'] == '1'
            exit 1
          end
        RUBY

        chmod 'bin/rails-active-mcp-server', 0o755
        say 'Created Rails binstub at bin/rails-active-mcp-server', :green

        # Create environment-aware wrapper for Claude Desktop compatibility
        ruby_path = `which ruby`.strip

        create_file 'bin/rails-active-mcp-wrapper', <<~BASH
          #!/usr/bin/env bash

          # Rails Active MCP Wrapper Script
          # Ensures correct Ruby environment for Claude Desktop execution

          # Fix Claude Desktop environment isolation issues
          export HOME="${HOME:-#{ENV['HOME']}}"
          export USER="${USER:-$(whoami)}"

          # Strategy 1: Use absolute Ruby path (most reliable)
          RUBY_PATH="#{ruby_path}"

          # Strategy 2: Try /usr/local/bin/ruby symlink as fallback
          if [ ! -x "$RUBY_PATH" ]; then
              RUBY_PATH="/usr/local/bin/ruby"
          fi

          # Strategy 3: Setup environment and use PATH resolution as last resort
          if [ ! -x "$RUBY_PATH" ]; then
              # Set up asdf environment if available
              export ASDF_DIR="$HOME/.asdf"
              if [ -f "$ASDF_DIR/asdf.sh" ]; then
                  source "$ASDF_DIR/asdf.sh"
              fi
          #{'    '}
              # Add version manager paths
              export PATH="$HOME/.asdf/shims:$HOME/.rbenv/shims:$HOME/.rvm/bin:$PATH"
              RUBY_PATH="ruby"
          fi

          # Change to the Rails project directory
          cd "$(dirname "$0")/.."

          # Execute with the determined Ruby path
          exec "$RUBY_PATH" bin/rails-active-mcp-server "$@"
        BASH

        chmod 'bin/rails-active-mcp-wrapper', 0o755
        say 'Created environment wrapper at bin/rails-active-mcp-wrapper', :green
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
        say "\nFor Claude Desktop configuration:", :green
        say 'Add this to your claude_desktop_config.json:', :yellow
        say '', :green
        say '{', :cyan
        say '  "mcpServers": {', :cyan
        say '    "rails-active-mcp": {', :cyan
        say "      \"command\": \"#{Rails.root}/bin/rails-active-mcp-wrapper\",", :cyan
        say "      \"cwd\": \"#{Rails.root}\",", :cyan
        say '      "env": {', :cyan
        say '        "RAILS_ENV": "development",', :cyan
        say "        \"HOME\": \"#{ENV['HOME']}\"", :cyan
        say '      }', :cyan
        say '    }', :cyan
        say '  }', :cyan
        say '}', :cyan
        say '', :green
        say "\nAvailable Tools in Claude Desktop:", :green
        say '- console_execute: Execute Ruby code with safety checks', :yellow
        say '- model_info: Get detailed information about Rails models', :yellow
        say '- safe_query: Execute safe read-only database queries', :yellow
        say '- dry_run: Analyze Ruby code for safety without execution', :yellow
        say '', :green
        say "\nWhy use the wrapper?", :green
        say '- Handles Ruby version manager environments (asdf, rbenv, etc.)', :yellow
        say '- Prevents "bundler version" and "Ruby version" conflicts', :yellow
        say '- Works reliably across different development setups', :yellow
        say "\nAlternative (if wrapper doesn't work):", :green
        say 'Use bin/rails-active-mcp-server instead of the wrapper', :yellow
        say "\nTesting:", :green
        say '1. Test manually: bin/rails-active-mcp-wrapper', :yellow
        say '2. Should output JSON responses (not plain text)', :yellow
        say '3. Restart Claude Desktop after config changes', :yellow
        say "\nTroubleshooting:", :green
        say '- Set RAILS_MCP_DEBUG=1 for verbose logging', :yellow
        say '- Check README.md for more configuration options', :yellow
        say "\nFor Ruby version manager users (asdf/rbenv/RVM):", :green
        say 'If you encounter "bundler version" errors, create a system symlink:', :yellow
        say "sudo ln -sf #{`which ruby`.strip} /usr/local/bin/ruby", :cyan
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
