#!/usr/bin/env ruby
# frozen_string_literal: true

# Generate system dependency data for RubyGems by analyzing README and extconf.rb files
#
# This script fetches gem data, parses documentation and build scripts, and uses
# pattern matching to identify system-level dependencies. It generates JSON files
# in data/rubygems/{gem_name}/{version}.json format.
#
# Features:
# - Non-destructive: Won't overwrite existing dependency data
# - Pattern matching: Uses configurable rules to identify dependencies
# - Multiple sources: Parses README, extconf.rb, and gem metadata
# - Extensible: Easy to add new patterns and detection methods
#
# Usage:
#   ruby scripts/generate_gem_dependencies.rb nokogiri
#   ruby scripts/generate_gem_dependencies.rb nokogiri 1.13.0
#   ruby scripts/generate_gem_dependencies.rb --all
#   ruby scripts/generate_gem_dependencies.rb --list popular_gems.txt

require_relative "lib/gem_fetcher"
require_relative "lib/readme_parser"
require_relative "lib/extconf_parser"
require_relative "lib/dependency_matcher"
require_relative "lib/json_generator"
require "optparse"
require "logger"
require "fileutils"

# Main orchestration class for gem dependency generation
class GemDependencyGenerator
  attr_reader :logger, :options

  def initialize(options = {})
    @options = {
      force: false,
      verbose: false,
      dry_run: false,
      output_dir: File.expand_path("../data/rubygems", __dir__)
    }.merge(options)

    @logger = Logger.new($stdout)
    @logger.level = @options[:verbose] ? Logger::DEBUG : Logger::INFO

    @gem_fetcher = GemFetcher.new(logger: @logger)
    @readme_parser = ReadmeParser.new(logger: @logger)
    @extconf_parser = ExtconfParser.new(logger: @logger)
    @dependency_matcher = DependencyMatcher.new(logger: @logger)
    @json_generator = JsonGenerator.new(logger: @logger)
  end

  # Process a single gem, optionally with a specific version
  #
  # @param gem_name [String] Name of the gem to process
  # @param version [String, nil] Specific version to process, or nil for all/latest
  # @return [Boolean] True if processing succeeded
  def process_gem(gem_name, version = nil)
    logger.info "Processing #{gem_name}#{version ? " (#{version})" : ''}..."

    versions = if version
                 [version]
               elsif @options[:latest_only]
                 # Get all versions and take the first (latest non-prerelease)
                 all_versions = @gem_fetcher.fetch_versions(gem_name)
                 stable = all_versions.reject { |v| v.include?("rc") || v.include?("beta") || v.include?("alpha") }
                 stable.empty? ? [all_versions.first] : [stable.first]
               else
                 @gem_fetcher.fetch_versions(gem_name)
               end

    if versions.empty?
      logger.warn "No versions found for #{gem_name}"
      return false
    end

    success_count = 0
    versions.each do |ver|
      success_count += 1 if process_gem_version(gem_name, ver)
    end

    # Only show summary if processing multiple versions
    if versions.size > 1
      logger.info "Processed #{success_count}/#{versions.size} versions of #{gem_name}"
    end

    success_count > 0
  rescue StandardError => e
    logger.error "Error processing #{gem_name}: #{e.message}"
    logger.debug e.backtrace.join("\n")
    false
  end

  # Process a specific gem version
  #
  # @param gem_name [String] Name of the gem
  # @param version [String] Version to process
  # @return [Boolean] True if processing succeeded
  def process_gem_version(gem_name, version)
    output_path = output_file_path(gem_name, version)

    if File.exist?(output_path) && !@options[:force]
      logger.info "Skipping #{gem_name} #{version} - data already exists (use --force to overwrite)"
      return true
    end

    logger.info "Analyzing #{gem_name} #{version}..."

    # Fetch gem data and extract files
    gem_data = @gem_fetcher.fetch_gem_data(gem_name, version)
    return false unless gem_data

    # Parse README for dependency hints
    readme_deps = @readme_parser.parse(gem_data[:readme])

    # Parse extconf.rb for library requirements
    extconf_deps = @extconf_parser.parse(gem_data[:extconf])

    # Combine and match dependencies to system packages
    all_hints = (readme_deps + extconf_deps).uniq
    dependencies = @dependency_matcher.match_dependencies(all_hints)

    # Output found dependencies
    if dependencies.any?
      logger.info "Found #{dependencies.size} system dependencies:"
      dependencies.each do |dep|
        logger.info "  - #{dep['name']} (#{dep['type']})"
      end
    else
      logger.info "No system dependencies found"
    end

    # Generate JSON output
    json_data = @json_generator.generate(
      gem_name: gem_name,
      version: version,
      dependencies: dependencies,
      notes: generate_notes(gem_data, all_hints)
    )

    # Write output file
    write_output(output_path, json_data)

    logger.info "✓ Generated dependency data for #{gem_name} #{version}"
    true
  rescue StandardError => e
    logger.error "Error processing #{gem_name} #{version}: #{e.message}"
    logger.debug e.backtrace.join("\n")
    false
  end

  # Process multiple gems from a list file
  #
  # @param list_file [String] Path to file containing gem names (one per line)
  # @return [Hash] Summary of results
  def process_list(list_file)
    gems = File.readlines(list_file).map(&:strip).reject { |line| line.empty? || line.start_with?("#") }

    results = { success: 0, failed: 0, skipped: 0 }

    gems.each do |gem_spec|
      gem_name, version = gem_spec.split(/\s+/, 2)
      if process_gem(gem_name, version)
        results[:success] += 1
      else
        results[:failed] += 1
      end
    end

    results
  end

  private

  # Generate output file path for a gem version
  def output_file_path(gem_name, version)
    File.join(@options[:output_dir], gem_name, "#{version}.json")
  end

  # Write JSON data to output file
  def write_output(path, data)
    return logger.info("DRY RUN: Would write to #{path}") if @options[:dry_run]

    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, data)
    logger.debug "Wrote #{data.bytesize} bytes to #{path}"
  end

  # Generate notes about the dependency detection process
  def generate_notes(gem_data, hints)
    notes = []

    notes << "Dependencies detected from README" if gem_data[:readme]
    notes << "Dependencies detected from extconf.rb" if gem_data[:extconf]
    notes << "Found #{hints.size} dependency hints: #{hints.join(', ')}" if hints.any?

    notes.join(". ")
  end
end

# Parse command line arguments
options = { latest_only: true } # Default to latest version only
OptionParser.new do |opts|
  opts.banner = "Usage: generate_gem_dependencies.rb [options] GEM_NAME [VERSION]"

  opts.on("-f", "--force", "Overwrite existing data") do
    options[:force] = true
  end

  opts.on("-v", "--verbose", "Verbose output") do
    options[:verbose] = true
  end

  opts.on("-n", "--dry-run", "Show what would be done without writing files") do
    options[:dry_run] = true
  end

  opts.on("-l", "--list FILE", "Process gems from list file") do |file|
    options[:list_file] = file
  end

  opts.on("--latest-only", "Process only the latest stable version (default)") do
    options[:latest_only] = true
  end

  opts.on("--all-versions", "Process all versions (can be slow)") do
    options[:latest_only] = false
  end

  opts.on("-o", "--output DIR", "Output directory (default: data/rubygems)") do |dir|
    options[:output_dir] = dir
  end

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit
  end
end.parse!

# Run the generator
generator = GemDependencyGenerator.new(options)

if options[:list_file]
  results = generator.process_list(options[:list_file])
  puts "\nResults: #{results[:success]} succeeded, #{results[:failed]} failed"
elsif ARGV.empty?
  puts "Error: No gem name specified"
  puts "Use --help for usage information"
  exit 1
else
  gem_name = ARGV[0]
  version = ARGV[1]
  success = generator.process_gem(gem_name, version)
  exit(success ? 0 : 1)
end
