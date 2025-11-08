# frozen_string_literal: true

# Parses README files to extract system dependency hints
#
# This class uses pattern matching to identify mentions of:
# - System libraries (libxml2, libpq, etc.)
# - Package names (postgresql-dev, zlib1g-dev, etc.)
# - Installation commands (apt-get install, brew install, etc.)
# - Dependency sections in documentation
#
# The parser is designed to be conservative, only extracting high-confidence
# dependency hints that can be validated by the DependencyMatcher.
class ReadmeParser
  # Common patterns for identifying system dependencies in documentation
  DEPENDENCY_PATTERNS = [
    # Library mentions: "requires libxml2", "needs libpq"
    /(?:requires?|needs?|depends?\s+on)\s+([a-z0-9_-]+(?:lib)?[a-z0-9_-]*)/i,

    # Installation commands: apt-get install libxml2-dev
    /(?:apt-get|apt|yum|dnf|brew|apk)\s+install\s+([a-z0-9_-]+)/i,

    # Development packages: libxml2-dev, postgresql-devel
    /\b([a-z0-9_-]+(?:-dev|-devel))\b/,

    # Common library names: libxml2, libxslt, libpq, libcurl
    /\b(lib[a-z0-9_-]+)\b/,

    # System dependencies section headers followed by package names
    /(?:system|native|external)\s+(?:dependencies|requirements|libraries)[:\s]*\n.*?([a-z0-9_-]+)/im,

    # "Install X" patterns
    /install\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)/,

    # Specific database/service mentions
    /\b(PostgreSQL|MySQL|Redis|SQLite|MongoDB|ImageMagick|FFmpeg|libffi|OpenSSL)\b/i
  ].freeze

  # Known library/package name variations that should be normalized
  LIBRARY_ALIASES = {
    "postgresql" => "postgresql",
    "postgres" => "postgresql",
    "libpq" => "postgresql",
    "mysql" => "mysql",
    "libmysqlclient" => "mysql",
    "sqlite" => "sqlite3",
    "sqlite3" => "sqlite3",
    "libxml2" => "libxml2",
    "libxslt" => "libxslt",
    "libxslt1" => "libxslt",
    "imagemagick" => "imagemagick",
    "libmagick" => "imagemagick",
    "redis" => "redis",
    "mongodb" => "mongodb",
    "libffi" => "libffi",
    "openssl" => "openssl",
    "libssl" => "openssl",
    "zlib" => "zlib",
    "libz" => "zlib",
    "curl" => "curl",
    "libcurl" => "curl",
    "ffmpeg" => "ffmpeg"
  }.freeze

  attr_reader :logger

  # Initialize the README parser
  #
  # @param logger [Logger] Logger instance for output
  def initialize(logger:)
    @logger = logger
  end

  # Parse a README file and extract dependency hints
  #
  # @param content [String, nil] README file content
  # @return [Array<String>] List of normalized dependency hints
  def parse(content)
    return [] if content.nil? || content.empty?

    logger.debug "Parsing README (#{content.bytesize} bytes)..."

    hints = []

    # Apply each pattern to the content
    DEPENDENCY_PATTERNS.each do |pattern|
      content.scan(pattern) do |match|
        hint = match.is_a?(Array) ? match.first : match
        normalized = normalize_hint(hint)
        hints << normalized if normalized
      end
    end

    # Remove duplicates and sort
    hints.uniq!
    hints.sort!

    logger.debug "Found #{hints.size} dependency hints in README: #{hints.join(', ')}"
    hints
  rescue StandardError => e
    logger.warn "Error parsing README: #{e.message}"
    []
  end

  private

  # Normalize a dependency hint to a standard form
  #
  # @param hint [String] Raw dependency hint
  # @return [String, nil] Normalized hint, or nil if invalid
  def normalize_hint(hint)
    return nil if hint.nil? || hint.empty?

    # Clean up the hint
    cleaned = hint.strip.downcase

    # Remove common suffixes
    cleaned = cleaned.sub(/-dev$/, "")
    cleaned = cleaned.sub(/-devel$/, "")

    # Check for known aliases
    return LIBRARY_ALIASES[cleaned] if LIBRARY_ALIASES.key?(cleaned)

    # Only return hints that look like valid library/package names
    # Must be at least 3 characters, alphanumeric with hyphens/underscores
    return nil unless cleaned.match?(/^[a-z0-9_-]{3,}$/)

    # Filter out common false positives
    return nil if false_positive?(cleaned)

    cleaned
  end

  # Check if a hint is likely a false positive
  #
  # @param hint [String] Normalized hint
  # @return [Boolean] True if likely a false positive
  def false_positive?(hint)
    false_positives = %w[
      the and for with from install require need
      ruby gem rails bundler rake rspec test
      development production staging test
      https http git github gitlab bitbucket
      readme license changelog contributing
      version latest stable master main
      example demo sample tutorial guide
      documentation docs api reference
      library libraries
    ]

    false_positives.include?(hint)
  end
end
