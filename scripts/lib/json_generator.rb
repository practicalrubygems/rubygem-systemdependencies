# frozen_string_literal: true

require "json"

# Generates JSON output files for gem system dependencies
#
# This class creates the standardized JSON structure used in the
# data/rubygems/ directory. The format is designed to be machine-readable
# and easy to integrate with build systems and CI pipelines.
class JsonGenerator
  attr_reader :logger

  # Initialize the JSON generator
  #
  # @param logger [Logger] Logger instance for output
  def initialize(logger:)
    @logger = logger
  end

  # Generate JSON data for a gem version
  #
  # @param gem_name [String] Name of the gem
  # @param version [String] Version of the gem
  # @param dependencies [Array<String>] List of system package categories
  # @param notes [String, nil] Optional notes about dependency detection
  # @return [String] JSON string
  def generate(gem_name:, version:, dependencies:, notes: nil)
    data = {
      gem: gem_name,
      version: version,
      dependencies: dependencies.sort,
      generated_at: Time.now.utc.iso8601,
      generator: "rubygem-systemdependencies"
    }

    # Add notes if provided
    data[:notes] = notes if notes && !notes.empty?

    # Add confidence level based on number of dependencies found
    data[:confidence] = confidence_level(dependencies.size)

    # Pretty-print JSON with 2-space indentation
    JSON.pretty_generate(data, indent: "  ", space: " ", object_nl: "\n", array_nl: "\n")
  rescue StandardError => e
    logger.error "Error generating JSON: #{e.message}"
    nil
  end

  private

  # Determine confidence level based on dependency count
  #
  # @param count [Integer] Number of dependencies found
  # @return [String] Confidence level (high/medium/low/unknown)
  def confidence_level(count)
    case count
    when 0
      "unknown"
    when 1..2
      "low"
    when 3..5
      "medium"
    else
      "high"
    end
  end
end
