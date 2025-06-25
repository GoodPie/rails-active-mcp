# frozen_string_literal: true

module RailsActiveMcp
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      desc 'Install Rails Active MCP'

      def create_initializer
        template 'initializer.rb', 'config/initializers/rails_active_mcp.rb'
      end

      def create_mcp_route
        route "mount ActionMCP::Engine, at: '/mcp' # Rails Active MCP"
      end

      def create_mcp_tools_directory
        empty_directory 'app/mcp/tools'
      end

      def copy_application_mcp_tool
        template 'application_mcp_tool.rb', 'app/mcp/tools/application_mcp_tool.rb'
      end

      def copy_mcp_tools
        %w[console_execute_tool safe_query_tool dry_run_tool model_info_tool].each do |tool|
          template "#{tool}.rb", "app/mcp/tools/rails_active_mcp_#{tool}.rb"
        end
      end

      def create_mcp_config
        template 'mcp.ru', 'mcp.ru'
      end

      def show_readme
        readme 'README' if behavior == :invoke
      end

      private

      def readme(path)
        say IO.read(File.join(source_root, path)), :green
      end
    end
  end
end
