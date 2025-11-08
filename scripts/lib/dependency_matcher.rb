# frozen_string_literal: true

require "yaml"

# Matches dependency hints to system package categories
#
# This class takes the raw hints extracted from README and extconf.rb files
# and maps them to the standardized system package categories used in
# data/system_packages/. It uses a configurable rules file to handle
# variations and aliases.
class DependencyMatcher
  attr_reader :logger, :rules

  # Initialize the dependency matcher
  #
  # @param logger [Logger] Logger instance for output
  # @param rules_file [String, nil] Path to rules YAML file
  def initialize(logger:, rules_file: nil)
    @logger = logger
    @rules = load_rules(rules_file)
  end

  # Match dependency hints to system package categories
  #
  # @param hints [Array<String>] List of dependency hints
  # @return [Array<String>] List of system package category names
  def match_dependencies(hints)
    return [] if hints.empty?

    logger.debug "Matching #{hints.size} hints to system packages..."

    matched = hints.map { |hint| match_hint(hint) }.compact.uniq.sort

    logger.debug "Matched to #{matched.size} system packages: #{matched.join(', ')}"
    matched
  end

  private

  # Load matching rules from YAML file
  #
  # @param rules_file [String, nil] Path to rules file
  # @return [Hash] Rules hash
  def load_rules(rules_file)
    rules_file ||= File.join(__dir__, "..", "config", "dependency_patterns.yml")

    if File.exist?(rules_file)
      YAML.load_file(rules_file)
    else
      logger.warn "Rules file not found: #{rules_file}, using built-in rules"
      default_rules
    end
  rescue StandardError => e
    logger.error "Error loading rules file: #{e.message}"
    default_rules
  end

  # Match a single hint to a system package category
  #
  # @param hint [String] Dependency hint
  # @return [String, nil] System package category name, or nil if no match
  def match_hint(hint)
    return nil if hint.nil? || hint.empty?

    # Direct match in rules
    if rules["mappings"].key?(hint)
      return rules["mappings"][hint]
    end

    # Pattern-based matching
    rules["patterns"]&.each do |pattern_data|
      pattern = Regexp.new(pattern_data["pattern"], Regexp::IGNORECASE)
      if hint.match?(pattern)
        return pattern_data["category"]
      end
    end

    # If no match found, check if it looks like a library name
    # and might have a corresponding system package directory
    if hint.start_with?("lib") || hint.include?("lib")
      logger.debug "Potential unmapped dependency: #{hint}"
      # Return the hint as-is, it might match a directory in data/system_packages/
      return hint
    end

    nil
  end

  # Default rules when no config file is available
  #
  # @return [Hash] Default rules structure
  def default_rules
    {
      "mappings" => {
        # Database libraries
        "postgresql" => "postgresql",
        "libpq" => "postgresql",
        "mysql" => "mysql",
        "libmysqlclient" => "mysql",
        "sqlite3" => "sqlite3",
        "sqlite" => "sqlite3",

        # XML/HTML processing
        "libxml2" => "libxml2",
        "libxslt" => "libxslt",

        # Compression
        "zlib" => "zlib",
        "libz" => "zlib",

        # SSL/Crypto
        "openssl" => "openssl",
        "libssl" => "openssl",
        "libcrypto" => "openssl",

        # Image processing
        "imagemagick" => "imagemagick",
        "libmagick" => "imagemagick",
        "libmagickwand" => "imagemagick",

        # Other common libraries
        "curl" => "curl",
        "libcurl" => "curl",
        "libffi" => "libffi",
        "redis" => "redis",
        "mongodb" => "mongodb",
        "ffmpeg" => "ffmpeg"
      },
      "patterns" => [
        { "pattern" => "\\bpostgres", "category" => "postgresql" },
        { "pattern" => "\\bmysql", "category" => "mysql" },
        { "pattern" => "\\bsqlite", "category" => "sqlite3" },
        { "pattern" => "\\bxml", "category" => "libxml2" },
        { "pattern" => "\\bxslt", "category" => "libxslt" },
        { "pattern" => "\\bssl|\\bopenssl", "category" => "openssl" },
        { "pattern" => "\\bmagick", "category" => "imagemagick" },
        { "pattern" => "\\bcurl", "category" => "curl" }
      ]
    }
  end
end
