# frozen_string_literal: true

module RailsActiveMcp
  class SafetyChecker
    DANGEROUS_PATTERNS = [
      { pattern: /\.delete_all\b/, description: 'Mass deletion of records', severity: :high },
      { pattern: /\.destroy_all\b/, description: 'Mass destruction of records', severity: :high },
      { pattern: /\.drop\b/, description: 'Database table dropping', severity: :critical },
      { pattern: /system\s*\(/, description: 'System command execution', severity: :critical },
      { pattern: /Kernel\.system\s*\(/, description: 'Kernel system command execution', severity: :critical },
      { pattern: /exec\s*\(/, description: 'Process execution', severity: :critical },
      { pattern: /`[^`]*`/, description: 'Shell command execution', severity: :critical },
      { pattern: /File\.delete/, description: 'File deletion', severity: :high },
      { pattern: /FileUtils\./, description: 'File system operations', severity: :high },
      { pattern: /Dir\.delete/, description: 'Directory deletion', severity: :high },
      { pattern: /ActiveRecord::Base\.connection\.execute/, description: 'Raw SQL execution', severity: :medium },
      { pattern: /\.update_all\(/, description: 'Mass update without callbacks', severity: :medium },
      { pattern: /eval\s*\(/, description: 'Dynamic code evaluation', severity: :high },
      { pattern: /send\s*\(/, description: 'Dynamic method calling', severity: :medium },
      { pattern: /const_set/, description: 'Dynamic constant definition', severity: :medium },
      { pattern: /remove_const/, description: 'Constant removal', severity: :high },
      { pattern: /undef_method/, description: 'Method removal', severity: :high },
      { pattern: /alias_method/, description: 'Method aliasing', severity: :medium },
      { pattern: /load\s*\(/, description: 'Code loading', severity: :medium },
      { pattern: /require\s*\(/, description: 'Library requiring', severity: :low },
      { pattern: /exit/, description: 'Process termination', severity: :high },
      { pattern: /abort/, description: 'Process abortion', severity: :high },
      { pattern: /fork/, description: 'Process forking', severity: :high },
      { pattern: /Thread\.new/, description: 'Thread creation', severity: :medium },
      { pattern: /\$LOAD_PATH/, description: 'Load path manipulation', severity: :medium },
      { pattern: /ENV\[/, description: 'Environment variable access', severity: :low },
      { pattern: /Rails\.env\s*=/, description: 'Environment changing', severity: :high },
      { pattern: /Rails\.application\.secrets/, description: 'Secrets access', severity: :medium }
    ].freeze

    READ_ONLY_PATTERNS = [
      /\.(find|find_by|find_each|find_in_batches)\b/,
      /\.(where|all|first|last|take)\b/,
      /\.(count|sum|average|maximum|minimum|size|length)\b/,
      /\.(pluck|ids|exists\?|empty\?|any\?|many\?)\b/,
      /\.(select|distinct|group|order|limit|offset)\b/,
      /\.(includes|joins|left_joins|preload|eager_load)\b/,
      /\.(to_a|to_sql|explain|inspect|as_json|to_json)\b/,
      /\.(attributes|attribute_names|column_names)\b/,
      /\.model_name\b/,
      /\.table_name\b/,
      /\.primary_key\b/,
      /\.connection\.schema_cache/,
      /Rails\.(env|root|application\.class|version)/
    ].freeze

    def initialize(config)
      @config = config
    end

    def safe?(code)
      analysis = analyze(code)
      analysis[:safe]
    end

    def analyze(code)
      violations = []

      # Check against dangerous patterns
      dangerous_patterns.each do |pattern_info|
        violations << pattern_info if code.match?(pattern_info[:pattern])
      end

      # Check custom patterns
      @config.custom_safety_patterns.each do |custom_pattern|
        next unless code.match?(custom_pattern[:pattern])

        violations << {
          pattern: custom_pattern[:pattern],
          description: custom_pattern[:description] || 'Custom safety rule',
          severity: :custom
        }
      end

      # Determine if code is read-only
      read_only = read_only?(code)

      # Calculate safety
      critical_violations = violations.select { |v| v[:severity] == :critical }
      high_violations = violations.select { |v| v[:severity] == :high }

      safe = (@config.safe_mode && read_only && critical_violations.empty? && high_violations.empty?) ||
             (!@config.safe_mode && critical_violations.empty?)

      {
        safe: safe,
        read_only: read_only,
        violations: violations,
        summary: generate_summary(violations, read_only)
      }
    end

    def read_only?(code)
      # Must contain at least one read-only pattern
      has_read_only = READ_ONLY_PATTERNS.any? { |pattern| code.match?(pattern) }

      # Must not contain any obvious mutation patterns
      mutation_patterns = [
        /\.(save|create|update|delete|destroy)\b/,
        /\.(save!|create!|update!|delete!|destroy!)\b/,
        /\.reload\b/,
        /\.transaction\b/,
        /=\s*[^=]/ # Assignment (basic check)
      ]

      has_mutations = mutation_patterns.any? { |pattern| code.match?(pattern) }

      has_read_only && !has_mutations
    end

    private

    def dangerous_patterns
      base_patterns = DANGEROUS_PATTERNS.dup

      # Add custom patterns from config
      @config.custom_safety_patterns.each do |custom|
        base_patterns << {
          pattern: custom[:pattern],
          description: custom[:description] || 'Custom rule',
          severity: :custom
        }
      end

      base_patterns
    end

    def generate_summary(violations, read_only)
      if violations.empty?
        read_only ? 'Code appears safe and read-only' : 'Code appears safe'
      else
        severity_counts = violations.group_by { |v| v[:severity] }.transform_values(&:count)
        parts = severity_counts.map do |severity, count|
          "#{count} #{severity} violation#{'s' if count > 1}"
        end

        "Found #{parts.join(', ')}"
      end
    end
  end
end
