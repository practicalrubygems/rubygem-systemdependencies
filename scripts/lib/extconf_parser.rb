# frozen_string_literal: true

# Parses extconf.rb files to extract library dependencies
#
# Ruby C extensions use extconf.rb to configure compilation. This file
# contains calls to mkmf methods that check for libraries, headers, and
# functions. By parsing these calls, we can identify required system libraries.
#
# Key methods parsed:
# - have_library(lib, func=nil): Checks for a library
# - find_library(lib, func, *paths): Finds a library in paths
# - have_header(header): Checks for a header file
# - pkg_config(pkg): Uses pkg-config to find library
# - dir_config(target): Configures paths for a library
class ExtconfParser
  # Patterns for extracting library names from extconf.rb
  LIBRARY_PATTERNS = [
    # have_library('libname') or have_library("libname")
    /have_library\s*\(\s*['"]([a-z0-9_-]+)['"]/i,

    # find_library('libname', ...) or find_library("libname", ...)
    /find_library\s*\(\s*['"]([a-z0-9_-]+)['"]/i,

    # pkg_config('package-name')
    /pkg_config\s*\(\s*['"]([a-z0-9_-]+)['"]/i,

    # dir_config('libname')
    /dir_config\s*\(\s*['"]([a-z0-9_-]+)['"]/i,

    # with_ldflags('-l<libname>')
    /with_ldflags\s*\(.*-l\s*([a-z0-9_-]+)/i,

    # $LIBS or $libs << '-l<libname>'
    /\$(?:LIBS|libs)\s*<<?\s*['"](?:-l\s*)?([a-z0-9_-]+)['"]/i
  ].freeze

  # Patterns for extracting header dependencies
  HEADER_PATTERNS = [
    # have_header('header.h')
    /have_header\s*\(\s*['"]([a-z0-9_\/-]+\.h)['"]/i,

    # find_header('header.h')
    /find_header\s*\(\s*['"]([a-z0-9_\/-]+\.h)['"]/i
  ].freeze

  # Map header files to common library names
  HEADER_TO_LIBRARY = {
    "postgresql/libpq-fe.h" => "postgresql",
    "libpq-fe.h" => "postgresql",
    "mysql.h" => "mysql",
    "mysql/mysql.h" => "mysql",
    "sqlite3.h" => "sqlite3",
    "libxml/parser.h" => "libxml2",
    "libxslt/xslt.h" => "libxslt",
    "curl/curl.h" => "curl",
    "openssl/ssl.h" => "openssl",
    "zlib.h" => "zlib",
    "ffi.h" => "libffi",
    "magic.h" => "libmagic",
    "MagickWand.h" => "imagemagick",
    "wand/MagickWand.h" => "imagemagick"
  }.freeze

  # Known library name variations
  LIBRARY_ALIASES = {
    "pq" => "postgresql",
    "mysql" => "mysql",
    "mysqlclient" => "mysql",
    "ssl" => "openssl",
    "crypto" => "openssl",
    "z" => "zlib",
    "xml2" => "libxml2",
    "xslt" => "libxslt",
    "curl" => "curl",
    "ffi" => "libffi",
    "magic" => "libmagic",
    "MagickWand" => "imagemagick",
    "MagickCore" => "imagemagick"
  }.freeze

  attr_reader :logger

  # Initialize the extconf.rb parser
  #
  # @param logger [Logger] Logger instance for output
  def initialize(logger:)
    @logger = logger
  end

  # Parse an extconf.rb file and extract library dependencies
  #
  # @param content [String, nil] extconf.rb file content
  # @return [Array<String>] List of normalized library names
  def parse(content)
    return [] if content.nil? || content.empty?

    logger.debug "Parsing extconf.rb (#{content.bytesize} bytes)..."

    dependencies = []

    # Extract library names from library check calls
    LIBRARY_PATTERNS.each do |pattern|
      content.scan(pattern) do |match|
        lib_name = match.is_a?(Array) ? match.first : match
        normalized = normalize_library_name(lib_name)
        dependencies << normalized if normalized
      end
    end

    # Extract dependencies from header checks
    HEADER_PATTERNS.each do |pattern|
      content.scan(pattern) do |match|
        header = match.is_a?(Array) ? match.first : match
        lib_name = header_to_library(header)
        dependencies << lib_name if lib_name
      end
    end

    # Remove duplicates and sort
    dependencies.uniq!
    dependencies.sort!

    logger.debug "Found #{dependencies.size} dependencies in extconf.rb: #{dependencies.join(', ')}"
    dependencies
  rescue StandardError => e
    logger.warn "Error parsing extconf.rb: #{e.message}"
    []
  end

  private

  # Normalize a library name extracted from extconf.rb
  #
  # @param lib_name [String] Raw library name
  # @return [String, nil] Normalized library name, or nil if invalid
  def normalize_library_name(lib_name)
    return nil if lib_name.nil? || lib_name.empty?

    cleaned = lib_name.strip.downcase

    # Remove common prefixes
    cleaned = cleaned.sub(/^lib/, "")

    # Check for known aliases
    return LIBRARY_ALIASES[cleaned] if LIBRARY_ALIASES.key?(cleaned)

    # Return the original library name if it looks valid
    cleaned.match?(/^[a-z0-9_-]{2,}$/) ? "lib#{cleaned}" : nil
  end

  # Map a header file to its corresponding library
  #
  # @param header [String] Header file name
  # @return [String, nil] Library name, or nil if unknown
  def header_to_library(header)
    # Direct mapping
    return HEADER_TO_LIBRARY[header] if HEADER_TO_LIBRARY.key?(header)

    # Try to infer from header name
    # e.g., "libxml/parser.h" -> "libxml2"
    if header =~ %r{^([a-z0-9_-]+)/}
      lib_name = Regexp.last_match(1)
      return lib_name if lib_name.start_with?("lib")
    end

    nil
  end
end
