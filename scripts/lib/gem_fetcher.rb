# frozen_string_literal: true

require "net/http"
require "json"
require "tmpdir"
require "rubygems/package"
require "zlib"
require "fileutils"

# Fetches gem metadata and extracts relevant files for dependency analysis
#
# This class handles:
# - Querying RubyGems.org API for gem information
# - Downloading gem .gem files
# - Extracting README and extconf.rb files
# - Caching downloads to avoid repeated fetches
class GemFetcher
  API_BASE = "https://rubygems.org/api/v1"
  GEM_BASE = "https://rubygems.org/gems"

  attr_reader :logger, :cache_dir

  # Initialize the gem fetcher
  #
  # @param logger [Logger] Logger instance for output
  # @param cache_dir [String] Directory for caching downloaded gems
  def initialize(logger:, cache_dir: nil)
    @logger = logger
    @cache_dir = cache_dir || File.join(Dir.tmpdir, "gem_dependency_cache")
    FileUtils.mkdir_p(@cache_dir)
  end

  # Fetch available versions for a gem
  #
  # @param gem_name [String] Name of the gem
  # @return [Array<String>] List of version strings
  def fetch_versions(gem_name)
    logger.debug "Fetching versions for #{gem_name}..."

    uri = URI("#{API_BASE}/versions/#{gem_name}.json")
    response = fetch_with_retry(uri)

    return [] unless response.is_a?(Net::HTTPSuccess)

    versions_data = JSON.parse(response.body)
    versions = versions_data.map { |v| v["number"] }

    logger.debug "Found #{versions.size} versions for #{gem_name}"
    versions
  rescue StandardError => e
    logger.error "Error fetching versions for #{gem_name}: #{e.message}"
    []
  end

  # Fetch gem data including README and extconf.rb
  #
  # @param gem_name [String] Name of the gem
  # @param version [String] Version to fetch
  # @return [Hash, nil] Hash with :readme and :extconf keys, or nil on error
  def fetch_gem_data(gem_name, version)
    cache_key = "#{gem_name}-#{version}"
    cached_path = File.join(@cache_dir, "#{cache_key}.gem")

    # Download gem if not cached
    unless File.exist?(cached_path)
      logger.debug "Downloading #{gem_name} #{version}..."
      download_gem(gem_name, version, cached_path)
    end

    # Extract relevant files
    extract_gem_files(cached_path)
  rescue StandardError => e
    logger.error "Error fetching gem data for #{gem_name} #{version}: #{e.message}"
    nil
  end

  private

  # Download a gem file
  #
  # @param gem_name [String] Name of the gem
  # @param version [String] Version to download
  # @param output_path [String] Where to save the gem file
  def download_gem(gem_name, version, output_path)
    uri = URI("#{GEM_BASE}/#{gem_name}-#{version}.gem")
    response = fetch_with_retry(uri)

    unless response.is_a?(Net::HTTPSuccess)
      raise "Failed to download gem: HTTP #{response.code}"
    end

    File.write(output_path, response.body, mode: "wb")
    logger.debug "Downloaded #{gem_name} #{version} (#{response.body.bytesize} bytes)"
  end

  # Extract README and extconf.rb from a gem file
  #
  # @param gem_path [String] Path to the .gem file
  # @return [Hash] Hash with :readme and :extconf content
  def extract_gem_files(gem_path)
    readme_content = nil
    extconf_content = nil

    # Use Gem::Package to properly handle gem files
    Gem::Package.new(gem_path).contents do |entry|
      case entry.full_name
      when /README/i
        # Found a README file
        readme_content ||= entry.read
        logger.debug "Found README: #{entry.full_name}"
      when %r{ext/.*/extconf\.rb$}
        # Found an extconf.rb file
        extconf_content ||= entry.read
        logger.debug "Found extconf.rb: #{entry.full_name}"
      end

      # Stop early if we found both files
      break if readme_content && extconf_content
    end

    # If Gem::Package.contents returned no files, try legacy method
    if readme_content.nil? && extconf_content.nil?
      logger.debug "Gem::Package.contents returned no files, trying legacy method"
      return extract_gem_files_legacy(gem_path)
    end

    {
      readme: readme_content,
      extconf: extconf_content
    }
  rescue StandardError => e
    logger.debug "Error extracting files from gem with Gem::Package: #{e.message}"
    # Try legacy tar.gz method as fallback
    extract_gem_files_legacy(gem_path)
  end

  # Legacy extraction method for older gem formats
  #
  # @param gem_path [String] Path to the .gem file
  # @return [Hash] Hash with :readme and :extconf content
  def extract_gem_files_legacy(gem_path)
    readme_content = nil
    extconf_content = nil

    # Try plain tar first (modern gem format), then gzipped tar (older format)
    File.open(gem_path, "rb") do |file|
      # Modern gems use plain tar for the outer container
      begin
        Gem::Package::TarReader.new(file) do |outer_tar|
          outer_tar.each do |outer_entry|
            next unless outer_entry.full_name == "data.tar.gz"

            # Found the data archive, now extract files from it
            Zlib::GzipReader.wrap(outer_entry) do |gzip|
              Gem::Package::TarReader.new(gzip) do |inner_tar|
                inner_tar.each do |entry|
                  case entry.full_name
                  when /README/i
                    readme_content ||= entry.read
                    logger.debug "Found README: #{entry.full_name}"
                  when %r{ext/.*/extconf\.rb$}
                    extconf_content ||= entry.read
                    logger.debug "Found extconf.rb: #{entry.full_name}"
                  end

                  break if readme_content && extconf_content
                end
              end
            end
          end
        end
      rescue Gem::Package::TarInvalidError
        # Fall back to gzipped tar for older gem formats
        file.rewind
        Gem::Package::TarReader.new(Zlib::GzipReader.new(file)) do |outer_tar|
          outer_tar.each do |outer_entry|
            next unless outer_entry.full_name == "data.tar.gz"

            # Found the data archive, now extract files from it
            Zlib::GzipReader.wrap(outer_entry) do |gzip|
              Gem::Package::TarReader.new(gzip) do |inner_tar|
                inner_tar.each do |entry|
                  case entry.full_name
                  when /README/i
                    readme_content ||= entry.read
                    logger.debug "Found README: #{entry.full_name}"
                  when %r{ext/.*/extconf\.rb$}
                    extconf_content ||= entry.read
                    logger.debug "Found extconf.rb: #{entry.full_name}"
                  end

                  break if readme_content && extconf_content
                end
              end
            end
          end
        end
      end
    end

    {
      readme: readme_content,
      extconf: extconf_content
    }
  rescue StandardError => e
    logger.warn "Error extracting files from gem: #{e.message}"
    { readme: nil, extconf: nil }
  end

  # Fetch a URI with retry logic
  #
  # @param uri [URI] URI to fetch
  # @param max_retries [Integer] Maximum number of retry attempts
  # @return [Net::HTTPResponse] HTTP response
  def fetch_with_retry(uri, max_retries: 3)
    retries = 0

    begin
      response = Net::HTTP.get_response(uri)

      # Handle redirects
      if response.is_a?(Net::HTTPRedirection)
        limit = max_retries
        while response.is_a?(Net::HTTPRedirection) && limit > 0
          uri = URI(response["location"])
          response = Net::HTTP.get_response(uri)
          limit -= 1
        end
      end

      response
    rescue StandardError => e
      retries += 1
      if retries <= max_retries
        logger.debug "Retry #{retries}/#{max_retries} for #{uri}"
        sleep(retries * 0.5)
        retry
      else
        raise
      end
    end
  end
end
