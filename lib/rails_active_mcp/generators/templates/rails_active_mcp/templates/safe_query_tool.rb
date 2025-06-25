class RailsActiveMcpSafeQueryTool < ApplicationMCPTool
  tool_name "safe_query"
  description "Execute safe read-only database queries on Rails models"

  property :model, type: "string", description: 'Model class name (e.g., "User", "Product")', required: true
  property :method, type: "string", description: 'Query method (find, where, count, etc.)', required: true
  property :args, type: "array", description: 'Arguments for the query method', required: false
  property :limit, type: "integer", description: 'Limit results (default: 100)', required: false

  def perform
    return render_disabled_error unless rails_active_mcp_enabled?

    model = properties[:model]
    method = properties[:method]
    args = properties[:args] || []
    limit = properties[:limit]

    executor = RailsActiveMcp::ConsoleExecutor.new(RailsActiveMcp.config)

    result = executor.execute_safe_query(
      model: model,
      method: method,
      args: args,
      limit: limit
    )

    if result[:success]
      output = []
      output << "Query: #{model}.#{method}(#{args.join(', ')})"
      output << "Count: #{result[:count]}"
      output << "Result: #{result[:result].inspect}"
      render(text: output.join("\n"))
    else
      render(error: [result[:error]])
    end
  end
end