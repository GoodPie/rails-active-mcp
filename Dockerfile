FROM ruby:3.4-slim

# Install system dependencies
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    git \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy gemspec and Gemfile first for better layer caching
COPY rails_active_mcp.gemspec Gemfile* ./
COPY lib/rails_active_mcp/version.rb ./lib/rails_active_mcp/

# Install gem dependencies
RUN bundle install

# Copy the rest of the application
COPY . .

# Default command
CMD ["bash"]
