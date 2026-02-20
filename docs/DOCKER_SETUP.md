# Docker Setup Guide

This guide explains how to develop and test Rails Active MCP without installing Ruby locally.

## Overview

The Docker setup provides:
- **No local Ruby installation required** - Everything runs in containers
- **Automated testing** - Run RSpec tests in Docker
- **Example Rails app** - Test the gem with a real Rails application
- **MCP client integration** - Connect Claude Desktop to the Dockerized MCP server

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running
- No Ruby installation needed!

## Quick Start

### 1. Build the Docker images

```bash
docker compose build
```

### 2. Run tests

```bash
# Run all tests
docker compose run --rm test

# Run a specific test file
docker compose run --rm test bundle exec rspec spec/rails_active_mcp/safety_checker_spec.rb

# Run with specific line number
docker compose run --rm test bundle exec rspec spec/rails_active_mcp/safety_checker_spec.rb:42

# Run linting
docker compose run --rm test bundle exec rubocop

# Auto-fix lint issues
docker compose run --rm test bundle exec rubocop -a
```

### 3. Interactive development shell

```bash
# Open a bash shell inside the container
docker compose run --rm dev

# Inside the container, you have access to all Ruby/Rails commands:
bundle exec rails console
bundle exec rspec
bundle exec rubocop
```

### 4. Test with an example Rails app

First, create an example Rails app (inside the dev container):

```bash
docker compose run --rm dev bash -c "
  cd /app && \
  rails new example --skip-git --database=sqlite3 && \
  cd example && \
  echo \"gem 'rails-active-mcp', path: '..'\" >> Gemfile && \
  bundle install && \
  rails generate rails_active_mcp:install
"
```

Then run the example app:

```bash
# Start the example Rails app on http://localhost:3000
docker compose up example-app
```

## Claude Desktop Integration

To connect Claude Desktop to the Dockerized MCP server:

### 1. Locate your Claude Desktop config

**macOS:**
```bash
~/Library/Application Support/Claude/claude_desktop_config.json
```

**Linux:**
```bash
~/.config/Claude/claude_desktop_config.json
```

**Windows:**
```
%APPDATA%\Claude\claude_desktop_config.json
```

### 2. Add the MCP server configuration

```json
{
  "mcpServers": {
    "rails-active-mcp": {
      "command": "/absolute/path/to/rails-active-mcp/bin/mcp-docker-wrapper",
      "args": []
    }
  }
}
```

**Important:** Replace `/absolute/path/to/rails-active-mcp` with the actual absolute path to this project.

### 3. Restart Claude Desktop

The MCP server will now run in Docker, and Claude Desktop will communicate with it via the wrapper script.

## How It Works

### Architecture

```
┌─────────────────┐
│ Claude Desktop  │  (Host machine)
│   (MCP Client)  │
└────────┬────────┘
         │ STDIO
         ↓
┌─────────────────────┐
│ mcp-docker-wrapper  │  (Shell script on host)
└────────┬────────────┘
         │ docker compose run
         ↓
┌─────────────────────────┐
│  Docker Container       │
│  ┌───────────────────┐  │
│  │  MCP Server       │  │
│  │  (Rails Active    │  │
│  │   MCP gem)        │  │
│  └───────────────────┘  │
└─────────────────────────┘
```

### Key Components

1. **Dockerfile** - Defines the Ruby environment with all dependencies
2. **docker-compose.yml** - Defines services for different use cases
3. **bin/mcp-docker-wrapper** - Shell script that bridges host MCP clients with Docker
4. **Volumes** - Persist bundle cache and example app database

### Services

- `test` - Run automated tests
- `mcp-server` - MCP server for client integration
- `example-app` - Example Rails application
- `dev` - Interactive development shell

## Common Commands

```bash
# Build or rebuild images after Gemfile changes
docker compose build

# Install new gems
docker compose run --rm dev bundle install

# Generate files (like YARD docs)
docker compose run --rm dev bundle exec yard doc

# Debug the MCP server
docker compose run --rm mcp-server env RAILS_MCP_DEBUG=1 bundle exec rails-active-mcp-server

# Clean up containers and volumes
docker compose down -v
```

## Troubleshooting

### "Permission denied" when running mcp-docker-wrapper

```bash
chmod +x bin/mcp-docker-wrapper
```

### Tests are slow on macOS

This is a known Docker Desktop limitation with file system mounts. Consider:
- Using [Docker Desktop with VirtioFS](https://docs.docker.com/desktop/settings/mac/#file-sharing) (faster)
- Running only specific tests instead of the full suite
- Using CI for full test runs

### Bundle install fails

```bash
# Rebuild the image
docker compose build --no-cache
```

### MCP client can't connect

1. Check the absolute path in Claude Desktop config
2. Verify Docker Desktop is running
3. Test the wrapper manually:
   ```bash
   echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | ./bin/mcp-docker-wrapper
   ```

## Development Workflow

### Daily development

```bash
# 1. Make code changes in your editor (files are mounted into container)

# 2. Run tests
docker compose run --rm test

# 3. Test with Claude Desktop using the wrapper script
# (Just use Claude Desktop normally - it will use Docker automatically)
```

### Adding dependencies

```bash
# 1. Edit Gemfile or rails_active_mcp.gemspec

# 2. Rebuild the image
docker compose build

# 3. Or install in a running container
docker compose run --rm dev bundle install
```

## CI/CD Integration

The same Docker setup can be used in GitHub Actions:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: docker compose run --rm test
```

## Benefits of This Setup

✅ **No local Ruby** - Completely isolated from your system
✅ **Consistent** - Same environment for everyone
✅ **Multi-version testing** - Easy to test against different Ruby/Rails versions
✅ **CI alignment** - Same Docker setup locally and in CI
✅ **MCP integration** - Still works with Claude Desktop
✅ **Clean** - `docker compose down -v` for complete reset

## Next Steps

- Create an example Rails app (see step 4 above)
- Set up Claude Desktop integration
- Explore the codebase using `docker compose run --rm dev bash`
- Run the test suite: `docker compose run --rm test`
