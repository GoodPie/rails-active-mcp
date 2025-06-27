# Testing the Rails Active MCP Generator

This guide explains how to test that your Rails Active MCP generator is working correctly.

## Quick Test in a New Rails App

1. **Create a test Rails app:**
   ```bash
   rails new test_mcp_app
   cd test_mcp_app
   ```

2. **Add your gem to the Gemfile:**
   ```ruby
   # Add to Gemfile
   gem 'rails-active-mcp', path: '/path/to/your/gem'
   # OR if published:
   gem 'rails-active-mcp'
   ```

3. **Bundle install:**
   ```bash
   bundle install
   ```

4. **Check if the generator is available:**
   ```bash
   rails generate --help
   ```
   You should see `rails_active_mcp:install` in the list.

5. **Run the generator:**
   ```bash
   rails generate rails_active_mcp:install
   ```

6. **Verify generated files:**
   - `config/initializers/rails_active_mcp.rb` should exist
   - `mcp.ru` should exist
   - `config/routes.rb` should have the mount line added

## What the Generator Should Create

### Initializer File
Location: `config/initializers/rails_active_mcp.rb`

Should contain:
- Configuration block with `RailsActiveMcp.configure`
- Environment-specific settings
- Safety and logging configuration

### MCP Server Configuration
Location: `mcp.ru`

Should contain:
- Rack configuration for standalone MCP server
- Proper requires and server initialization

### Route Addition
In `config/routes.rb`:
- Should add: `mount RailsActiveMcp::McpServer.new, at: '/mcp'`

## Generator Commands to Test

```bash
# See generator help
rails generate rails_active_mcp:install --help

# Run with verbose output
rails generate rails_active_mcp:install --verbose

# Skip files (for testing)
rails generate rails_active_mcp:install --skip-route
```

## Common Issues and Solutions

### Generator Not Found
If `rails generate rails_active_mcp:install` returns "Could not find generator", check:

1. **Gem is properly installed:** `bundle list | grep rails-active-mcp`
2. **Generator file exists:** Check `lib/generators/rails_active_mcp/install/install_generator.rb`
3. **Class name matches:** Ensure class is `RailsActiveMcp::Generators::InstallGenerator`
4. **Engine is loaded:** Check that the Engine is being required

### Files Not Generated
If files aren't created:

1. **Check permissions:** Ensure Rails can write to the directories
2. **Check templates:** Verify template files exist in `templates/` directory
3. **Check source_root:** Ensure `source_root` points to correct directory

### Route Not Added
If the route isn't added to `config/routes.rb`:

1. **Check routes.rb exists:** Generator requires existing routes file
2. **File permissions:** Ensure routes.rb is writable

## Running Tests

Run the generator specs:
```bash
bundle exec rspec spec/generators/
```

## Debugging Generator Issues

Add debugging to your generator:
```ruby
def create_initializer
  say "Creating initializer at: #{destination_root}/config/initializers/rails_active_mcp.rb"
  template 'initializer.rb', 'config/initializers/rails_active_mcp.rb'
  say "Initializer created successfully", :green
end
```

Check Rails generator resolution:
```ruby
# In rails console
Rails::Generators.find_by_namespace("rails_active_mcp:install")
``` 