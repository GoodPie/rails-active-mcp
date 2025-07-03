# frozen_string_literal: true

module RailsActiveMcp
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__ || File.dirname(__FILE__))

      desc 'Install Rails Active MCP'

      def create_initializer
        template 'initializer.rb', 'config/initializers/rails_active_mcp.rb'
      end

      def create_wrapper_script
        template 'rails-active-mcp-wrapper', 'bin/rails-active-mcp-wrapper'
        chmod 'bin/rails-active-mcp-wrapper', 0o755
      end

      def create_server_script
        template 'rails-active-mcp-server', 'bin/rails-active-mcp-server'
        chmod 'bin/rails-active-mcp-server', 0o755
      end

      def create_mcp_config
        template 'mcp.ru', 'mcp.ru'
      end

      def show_readme
        readme 'README.md' if behavior == :invoke
      end

      # rubocop:disable Metrics/AbcSize
      def show_post_install_instructions
        return unless behavior == :invoke

        say "\n#{'=' * 50}", :green
        say 'Rails Active MCP Installation Complete!', :green
        say '=' * 50, :green
        say "\nFiles created:", :green
        say '✅ config/initializers/rails_active_mcp.rb', :yellow
        say '✅ bin/rails-active-mcp-wrapper', :yellow
        say '✅ bin/rails-active-mcp-server', :yellow
        say '✅ mcp.ru', :yellow
        say '', :green
        say "\nQuick Test:", :green
        say '1. Test the server: bin/rails-active-mcp-wrapper', :yellow
        say '2. Should show JSON responses (not plain text)', :yellow
        say '3. Exit with Ctrl+C', :yellow
        say '', :green
        say "\nFor Claude Desktop configuration:", :green
        say 'Add this to your claude_desktop_config.json:', :yellow
        say '', :green
        say '{', :cyan
        say '  "mcpServers": {', :cyan
        say '    "rails-active-mcp": {', :cyan
        say "      \"command\": \"#{Rails.root.join('bin/rails-active-mcp-wrapper')}\",", :cyan
        say "      \"cwd\": \"#{Rails.root}\",", :cyan
        say '      "env": {', :cyan
        say '        "RAILS_ENV": "development"', :cyan
        say '      }', :cyan
        say '    }', :cyan
        say '  }', :cyan
        say '}', :cyan
        say '', :green
        say 'Config file locations:', :green
        say '  macOS: ~/.config/claude-desktop/claude_desktop_config.json', :yellow
        say '  Windows: %APPDATA%\\Claude\\claude_desktop_config.json', :yellow
        say '', :green
        say "\nAvailable Tools in Claude Desktop:", :green
        say '- console_execute: Execute Ruby code with safety checks', :yellow
        say '- model_info: Get detailed information about Rails models', :yellow
        say '- safe_query: Execute safe read-only database queries', :yellow
        say '- dry_run: Analyze Ruby code for safety without execution', :yellow
        say '', :green
        say "\nExample Claude Desktop prompts:", :green
        say '- "Show me the User model structure"', :yellow
        say '- "How many users were created in the last week?"', :yellow
        say '- "What are the most recent orders?"', :yellow
        say '- "Check if this code is safe: User.delete_all"', :yellow
        say '', :green
        say "\nTroubleshooting:", :green
        say '- Debug mode: RAILS_MCP_DEBUG=1 bin/rails-active-mcp-wrapper', :yellow
        say '- Check status: rails rails_active_mcp:status', :yellow
        say '- Restart Claude Desktop after config changes', :yellow
        say '- If wrapper fails, try: bin/rails-active-mcp-server', :yellow
        say '', :green
        say "\nNext steps:", :green
        say '1. Test installation: rails rails_active_mcp:test_tools', :yellow
        say '2. Configure Claude Desktop (see above)', :yellow
        say '3. Restart Claude Desktop', :yellow
        say '4. Start chatting with your Rails app!', :yellow
        say '=' * 50, :green
      end
      # rubocop:enable Metrics/AbcSize

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
