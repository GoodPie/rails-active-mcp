# frozen_string_literal: true

module RailsActiveMcp
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__ || File.dirname(__FILE__))

      desc 'Install Rails Active MCP'

      def create_initializer
        template 'initializer.rb', 'config/initializers/rails_active_mcp.rb'
      end

      def show_readme
        readme 'README.md' if behavior == :invoke
      end

      def show_post_install_instructions
        return unless behavior == :invoke

        say "\n#{'=' * 50}", :green
        say 'Rails Active MCP Installation Complete!', :green
        say '=' * 50, :green
        say "\nFor Claude Desktop configuration:", :green
        say 'Add this to your claude_desktop_config.json:', :yellow
        say '', :green
        say '{', :cyan
        say '  "mcpServers": {', :cyan
        say '    "rails-active-mcp": {', :cyan
        say "      \"command\": \"#{Rails.root.join('bin/rails-active-mcp-wrapper",')}", :cyan
        say "      \"cwd\": \"#{Rails.root}\",", :cyan
        say '      "env": {', :cyan
        say '        "RAILS_ENV": "development",', :cyan
        say "        \"HOME\": \"#{Dir.home}\"", :cyan
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
          say File.read(readme_path), :green
        else
          say "README file not found at #{readme_path}", :green
        end
      rescue StandardError => e
        say "Error reading README: #{e.message}", :red
      end
    end
  end
end
