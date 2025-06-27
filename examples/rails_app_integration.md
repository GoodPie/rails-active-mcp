# Rails Active MCP - Real-World Integration Examples

This guide demonstrates how to integrate Rails Active MCP in various real-world scenarios, following the best practices outlined in the [Rails application structure guide](https://dev.to/kimrgrey/tuning-rails-application-structure-5f74).

## E-commerce Application Example

### Model Setup
```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_many :orders, dependent: :destroy
  has_one :profile, dependent: :destroy
  
  validates :email, presence: true, uniqueness: true
  scope :active, -> { where(active: true) }
end

# app/models/order.rb
class Order < ApplicationRecord
  belongs_to :user
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items
  
  validates :total_amount, presence: true, numericality: { greater_than: 0 }
  scope :recent, -> { where('created_at > ?', 1.week.ago) }
end

# app/models/product.rb
class Product < ApplicationRecord
  has_many :order_items
  has_many :orders, through: :order_items
  
  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  scope :available, -> { where(available: true) }
end
```

### Configuration for E-commerce
```ruby
# config/initializers/rails_active_mcp.rb
RailsActiveMcp.configure do |config|
  # Core safety settings
  config.safe_mode = true
  config.max_results = 100
  config.command_timeout = 30
  
  # Environment-specific settings
  case Rails.env
  when 'production'
    # Strict production settings
    config.safe_mode = true
    config.max_results = 50
    config.command_timeout = 15
    config.log_executions = true
    
    # Only allow safe models in production
    config.allowed_models = %w[User Order Product OrderItem]
    
  when 'development'
    # More permissive for development
    config.safe_mode = false
    config.max_results = 200
    config.command_timeout = 60
    config.log_level = :debug
    
  when 'staging'
    # Production-like but slightly more permissive
    config.safe_mode = true
    config.max_results = 100
    config.command_timeout = 30
    config.log_executions = true
  end
  
  # Custom safety patterns for e-commerce
  config.custom_safety_patterns = [
    { 
      pattern: /payment.*delete|destroy.*payment/i, 
      description: "Payment data modification is dangerous" 
    },
    { 
      pattern: /User.*\.update_all.*role/i, 
      description: "Mass role updates are dangerous" 
    }
  ]
end
```

### Claude Desktop Queries for E-commerce

#### Sales Analytics
```ruby
# Ask Claude: "What are our sales metrics for the last week?"
Order.recent.sum(:total_amount)
Order.recent.count
Order.recent.average(:total_amount)

# Ask Claude: "Who are our top customers by order value?"
User.joins(:orders)
    .group('users.id', 'users.email')
    .order('SUM(orders.total_amount) DESC')
    .limit(10)
    .pluck('users.email', 'SUM(orders.total_amount)')
```

#### Inventory Management
```ruby
# Ask Claude: "Which products are running low on inventory?"
Product.where('inventory_count < ?', 10)
        .order(:inventory_count)
        .pluck(:name, :inventory_count)

# Ask Claude: "What are our best-selling products this month?"
Product.joins(:order_items)
       .where(order_items: { created_at: 1.month.ago.. })
       .group(:name)
       .order('COUNT(*) DESC')
       .limit(10)
       .count
```

#### Customer Support
```ruby
# Ask Claude: "Find recent orders for customer email@example.com"
User.find_by(email: 'email@example.com')
    &.orders
    &.recent
    &.includes(:products)
    &.map { |o| { id: o.id, total: o.total_amount, products: o.products.pluck(:name) } }

# Ask Claude: "Check the User model structure"
# Uses model_info tool to show schema, associations, validations
```

## SaaS Application Example

### Multi-tenant Setup
```ruby
# app/models/account.rb
class Account < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :projects, dependent: :destroy
  
  validates :name, presence: true
  validates :plan, inclusion: { in: %w[free pro enterprise] }
end

# app/models/project.rb
class Project < ApplicationRecord
  belongs_to :account
  belongs_to :user, -> { where(role: 'owner') }
  has_many :tasks, dependent: :destroy
  
  validates :name, presence: true
  scope :active, -> { where(archived: false) }
end
```

### SaaS-specific Configuration
```ruby
# config/initializers/rails_active_mcp.rb
RailsActiveMcp.configure do |config|
  config.safe_mode = true
  config.max_results = 100
  
  # Tenant isolation safety
  config.custom_safety_patterns = [
    { 
      pattern: /Account.*delete_all|destroy_all/i, 
      description: "Account mass operations are forbidden" 
    },
    { 
      pattern: /User.*update_all.*account_id/i, 
      description: "Cross-tenant user moves are dangerous" 
    }
  ]
  
  # Production tenant restrictions
  if Rails.env.production?
    config.allowed_models = %w[Account User Project Task]
    config.max_results = 50
  end
end
```

### Claude Queries for SaaS Analytics
```ruby
# Ask Claude: "How many active accounts do we have by plan?"
Account.group(:plan).count

# Ask Claude: "What's our monthly recurring revenue?"
Account.where(plan: ['pro', 'enterprise'])
       .sum('CASE 
             WHEN plan = "pro" THEN 29 
             WHEN plan = "enterprise" THEN 99 
             ELSE 0 END')

# Ask Claude: "Which accounts have the most projects?"
Account.joins(:projects)
       .group('accounts.name')
       .order('COUNT(projects.id) DESC')
       .limit(10)
       .count
```

## Content Management System Example

### CMS Model Structure
```ruby
# app/models/article.rb
class Article < ApplicationRecord
  belongs_to :author, class_name: 'User'
  belongs_to :category
  has_many :comments, dependent: :destroy
  
  validates :title, presence: true
  validates :content, presence: true
  
  scope :published, -> { where(published: true) }
  scope :recent, -> { order(created_at: :desc) }
end

# app/models/category.rb
class Category < ApplicationRecord
  has_many :articles
  validates :name, presence: true, uniqueness: true
end
```

### CMS Configuration
```ruby
# config/initializers/rails_active_mcp.rb
RailsActiveMcp.configure do |config|
  config.safe_mode = true
  
  # Content-specific safety patterns
  config.custom_safety_patterns = [
    { 
      pattern: /Article.*delete_all.*published.*true/i, 
      description: "Mass deletion of published articles is dangerous" 
    }
  ]
  
  # Environment-specific settings
  case Rails.env
  when 'production'
    config.allowed_models = %w[Article Category User Comment]
    config.max_results = 25  # Smaller for content queries
  end
end
```

### Claude Queries for Content Analytics
```ruby
# Ask Claude: "What are our most popular categories?"
Category.joins(:articles)
        .where(articles: { published: true })
        .group(:name)
        .order('COUNT(articles.id) DESC')
        .count

# Ask Claude: "Show me recent article performance"
Article.published
       .recent
       .limit(10)
       .pluck(:title, :views_count, :created_at)

# Ask Claude: "Find articles that need moderation"
Article.joins(:comments)
       .where(comments: { flagged: true })
       .distinct
       .pluck(:title, :id)
```

## Advanced Safety Patterns

### Custom Validators
```ruby
# config/initializers/rails_active_mcp.rb
RailsActiveMcp.configure do |config|
  # Financial data protection
  config.custom_safety_patterns += [
    { pattern: /payment|billing|card|bank/i, description: "Financial data access" },
    { pattern: /password|token|secret|key/i, description: "Sensitive credential access" },
    { pattern: /delete.*where.*id.*in/i, description: "Bulk deletion by ID list" }
  ]
  
  # Model-specific restrictions
  config.allowed_models = case Rails.env
  when 'production'
    %w[User Order Product Customer Invoice]  # Whitelist approach
  else
    []  # Empty = allow all models
  end
end
```

### Environment-specific Presets
```ruby
# config/initializers/rails_active_mcp.rb
RailsActiveMcp.configure do |config|
  case Rails.env
  when 'production'
    # Ultra-safe production mode
    config.safe_mode = true
    config.command_timeout = 10
    config.max_results = 25
    config.log_executions = true
    
  when 'staging' 
    # Production-like testing
    config.safe_mode = true
    config.command_timeout = 20
    config.max_results = 50
    config.log_executions = true
    
  when 'development'
    # Developer-friendly
    config.safe_mode = false
    config.command_timeout = 60
    config.max_results = 200
    config.log_level = :debug
    
  when 'test'
    # Fast and minimal for tests
    config.safe_mode = true
    config.command_timeout = 5
    config.max_results = 10
    config.log_executions = false
  end
end
```

## Best Practices

### 1. Always Use Limits
```ruby
# ✅ Good - Always include limits
User.where(active: true).limit(10)
Order.recent.limit(20)

# ❌ Avoid - Unlimited queries can overwhelm Claude
User.all
Order.where(status: 'pending')
```

### 2. Prefer Aggregations Over Raw Data
```ruby
# ✅ Good - Summary data
User.group(:status).count
Order.group_by_day(:created_at).sum(:total_amount)

# ❌ Less useful - Raw data dumps
User.pluck(:email, :status, :created_at)
```

### 3. Use Meaningful Scopes
```ruby
# ✅ Good - Readable business logic
User.active.recent_signups.count
Order.completed.this_month.sum(:total_amount)

# ❌ Less clear - Complex inline conditions
User.where(active: true, created_at: 1.week.ago..).count
```

### 4. Structure Claude Queries Naturally
```ruby
# Ask Claude natural questions:
# "How many users signed up this week?"
# "What's our average order value?"
# "Which products need restocking?"
# "Show me the User model structure"
```

## Troubleshooting Common Issues

### Performance Issues
```ruby
# Monitor execution times
rails rails_active_mcp:benchmark

# Check for slow queries
rails rails_active_mcp:status
```

### Safety Violations
```ruby
# Test code safety before asking Claude
rails rails_active_mcp:check_safety['User.delete_all']

# View current configuration
rails rails_active_mcp:validate_config
```

### Claude Desktop Integration
```ruby
# Generate Claude Desktop config
rails rails_active_mcp:install_claude_config

# Test server connectivity  
bin/rails-active-mcp-wrapper
```

This comprehensive integration guide helps Rails developers understand how to effectively use Rails Active MCP in real-world applications, following modern Rails patterns and ensuring secure, efficient AI-powered database interactions. 