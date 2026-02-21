# frozen_string_literal: true

module RailsActiveMcp
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__ || File.dirname(__FILE__))

      desc 'Install Rails Active MCP'

      MCP_CLIENTS = {
        'claude_code' => { name: 'Claude Code', path: '.mcp.json', key: 'mcpServers' },
        'cursor' => { name: 'Cursor', path: '.cursor/mcp.json', key: 'mcpServers' },
        'vscode' => { name: 'VS Code / GitHub Copilot', path: '.vscode/mcp.json', key: 'servers' },
        'claude_desktop' => { name: 'Claude Desktop', path: nil },
        'windsurf' => { name: 'Windsurf', path: nil }
      }.freeze

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

      def create_mcp_client_configs
        return unless behavior == :invoke

        say "\nWhich MCP clients do you use?", :green
        say '(Select all that apply, separated by commas)', :yellow
        say ''

        client_keys = MCP_CLIENTS.keys
        client_keys.each_with_index do |key, index|
          say "  #{index + 1}. #{MCP_CLIENTS[key][:name]}", :cyan
        end
        say "  #{client_keys.size + 1}. Skip (configure manually later)", :cyan
        say ''

        response = ask('Enter your choices (e.g. 1,2,3):', :green)
        @selected_clients = parse_client_selections(response, client_keys)

        generate_client_configs
      end

      def show_post_install_instructions
        return unless behavior == :invoke

        say "\n#{'=' * 50}", :green
        say 'Rails Active MCP Installation Complete!', :green
        say('=' * 50, :green)

        show_created_files
        show_quick_test
        show_global_client_instructions
        show_available_tools
        show_example_prompts
        show_troubleshooting
        show_next_steps
      end

      private

      def parse_client_selections(response, client_keys)
        return [] if response.blank?

        indices = response.split(',').map { |s| s.strip.to_i - 1 }
        indices.filter_map { |i| client_keys[i] if i >= 0 && i < client_keys.size }
      end

      def generate_client_configs
        @selected_clients.each do |client_key|
          client = MCP_CLIENTS[client_key]
          next unless client[:path]

          write_client_config(client_key, client)
        end
      end

      def write_client_config(client_key, client)
        path = client[:path]
        full_path = File.join(destination_root, path)
        top_key = client[:key]

        dir = File.dirname(path)
        FileUtils.mkdir_p(File.join(destination_root, dir)) unless dir == '.'

        server_entry = build_server_entry

        if File.exist?(full_path)
          merge_into_existing_config(full_path, path, top_key, server_entry, client[:name])
        else
          config = { top_key => { 'rails-active-mcp' => server_entry } }
          create_file path, "#{JSON.pretty_generate(config)}\n"
          say "  Created #{path} for #{client[:name]}", :green
        end

        return unless client_key == 'vscode'

        append_to_gitignore('.vscode/mcp.json')
      end

      def merge_into_existing_config(full_path, path, top_key, server_entry, client_name)
        existing = JSON.parse(File.read(full_path))
        existing[top_key] ||= {}

        if existing[top_key].key?('rails-active-mcp')
          say "  Skipped #{path} — rails-active-mcp already configured for #{client_name}", :yellow
          return
        end

        existing[top_key]['rails-active-mcp'] = server_entry
        File.write(full_path, "#{JSON.pretty_generate(existing)}\n")
        say "  Updated #{path} — added rails-active-mcp for #{client_name}", :green
      rescue JSON::ParserError
        say "  Skipped #{path} — file exists but contains invalid JSON", :red
      end

      def build_server_entry
        {
          'command' => Rails.root.join('bin/rails-active-mcp-wrapper').to_s,
          'args' => [],
          'env' => { 'RAILS_ENV' => 'development' }
        }
      end

      def build_mcp_config(top_key)
        { top_key => { 'rails-active-mcp' => build_server_entry } }
      end

      def append_to_gitignore(entry)
        gitignore_path = File.join(destination_root, '.gitignore')
        return unless File.exist?(gitignore_path)

        content = File.read(gitignore_path)
        return if content.include?(entry)

        append_to_file '.gitignore', "\n# MCP client config (may contain local paths)\n#{entry}\n"
      end

      def show_created_files
        say "\nFiles created:", :green
        say '  config/initializers/rails_active_mcp.rb', :yellow
        say '  bin/rails-active-mcp-wrapper', :yellow
        say '  bin/rails-active-mcp-server', :yellow
        say '  mcp.ru', :yellow

        return unless @selected_clients&.any?

        @selected_clients.each do |key|
          path = MCP_CLIENTS[key][:path]
          say "  #{path}", :yellow if path
        end
      end

      def show_quick_test
        say "\nQuick Test:", :green
        say '  1. Test the server: bin/rails-active-mcp-wrapper', :yellow
        say '  2. Should show JSON responses (not plain text)', :yellow
        say '  3. Exit with Ctrl+C', :yellow
      end

      def show_global_client_instructions
        global_clients = (@selected_clients || []).select { |key| MCP_CLIENTS[key][:path].nil? }
        return if global_clients.empty?

        say "\nManual configuration needed for:", :green

        show_claude_desktop_instructions if global_clients.include?('claude_desktop')

        return unless global_clients.include?('windsurf')

        show_windsurf_instructions
      end

      def show_claude_desktop_instructions
        say "\n  Claude Desktop:", :cyan
        say '  Add this to your claude_desktop_config.json:', :yellow
        say '  macOS: ~/.config/claude-desktop/claude_desktop_config.json', :yellow
        say '  Windows: %APPDATA%\\Claude\\claude_desktop_config.json', :yellow
        say ''
        say "  #{JSON.pretty_generate(build_mcp_config('mcpServers')).gsub("\n", "\n  ")}", :cyan
      end

      def show_windsurf_instructions
        say "\n  Windsurf:", :cyan
        say '  Add this to ~/.codeium/windsurf/mcp_config.json:', :yellow
        say ''
        say "  #{JSON.pretty_generate(build_mcp_config('mcpServers')).gsub("\n", "\n  ")}", :cyan
      end

      def show_available_tools
        say "\nAvailable MCP Tools:", :green
        say '  console_execute - Execute Ruby code with safety checks', :yellow
        say '  model_info      - Get detailed information about Rails models', :yellow
        say '  safe_query      - Execute safe read-only database queries', :yellow
        say '  dry_run         - Analyze Ruby code for safety without execution', :yellow
      end

      def show_example_prompts
        say "\nExample prompts:", :green
        say '  "Show me the User model structure"', :yellow
        say '  "How many users were created in the last week?"', :yellow
        say '  "What are the most recent orders?"', :yellow
        say '  "Check if this code is safe: User.delete_all"', :yellow
      end

      def show_troubleshooting
        say "\nTroubleshooting:", :green
        say '  Debug mode: RAILS_MCP_DEBUG=1 bin/rails-active-mcp-wrapper', :yellow
        say '  If wrapper fails, try: bin/rails-active-mcp-server directly', :yellow
      end

      def show_next_steps
        say "\nNext steps:", :green
        say '  1. Test installation: rails rails_active_mcp:test_tools', :yellow

        if @selected_clients.blank?
          say '  2. Configure your MCP client (see README)', :yellow
        else
          global_clients = @selected_clients.select { |key| MCP_CLIENTS[key][:path].nil? }
          if global_clients.any?
            say '  2. Add the config above to your global MCP client settings', :yellow
          else
            say '  2. Open your project in your MCP client - it should auto-detect the server', :yellow
          end
        end

        say '  3. Start chatting with your Rails app!', :yellow
        say('=' * 50, :green)
      end
    end
  end
end
