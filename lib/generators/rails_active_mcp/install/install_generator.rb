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
        route "mount RailsActiveMcp::McpServer.new, at: '/mcp' # Rails Active MCP"
      end

      def create_mcp_config
        template 'mcp.ru', 'mcp.ru'
      end

      def show_readme
        readme 'README.md' if behavior == :invoke
      end

      private

      def readme(path)
        readme_path = File.join(self.class.source_root, path)
        if File.exist?(readme_path)
          say IO.read(readme_path), :green
        else
          say "README file not found at #{readme_path}", :yellow
        end
      rescue StandardError => e
        say "Error reading README: #{e.message}", :red
      end
    end
  end
end
