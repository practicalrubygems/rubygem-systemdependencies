#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'tmpdir'

class RubyGemTester
  SUPPORTED_DISTROS = {
    'debian' => 'debian:bookworm-slim',
    'ubuntu' => 'ubuntu:22.04',
    'alpine' => 'alpine:3.18',
    'fedora' => 'fedora:38',
    'arch' => 'archlinux:latest'
  }.freeze

  RUBY_INSTALL_COMMANDS = {
    'debian' => 'apt-get update -qq && apt-get install -y --no-install-recommends ruby ruby-dev build-essential && apt-get clean && rm -rf /var/lib/apt/lists/*',
    'ubuntu' => 'apt-get update -qq && apt-get install -y --no-install-recommends ruby ruby-dev build-essential && apt-get clean && rm -rf /var/lib/apt/lists/*',
    'alpine' => 'apk add --no-cache ruby ruby-dev build-base',
    'fedora' => 'dnf install -y ruby ruby-devel gcc gcc-c++ make && dnf clean all',
    'arch' => 'pacman -Sy --noconfirm ruby base-devel'
  }.freeze

  def initialize(gem_name, version: nil, distro: 'debian')
    @gem_name = gem_name
    @version = version
    @distro = distro
    @base_dir = File.expand_path('..', __dir__)
    @data_dir = File.join(@base_dir, 'data')

    validate_distro!
    load_dependency_aliases
    load_gem_data
  end

  def test
    puts "Testing #{@gem_name}#{@version ? " v#{@version}" : ''} on #{@distro}"
    puts "=" * 80

    Dir.mktmpdir do |tmpdir|
      dockerfile_path = create_dockerfile(tmpdir)

      success = build_and_run_container(tmpdir, dockerfile_path)

      if success
        puts "\n✓ SUCCESS: #{@gem_name} installed successfully on #{@distro}"
        true
      else
        puts "\n✗ FAILED: #{@gem_name} installation failed on #{@distro}"
        false
      end
    end
  end

  private

  def validate_distro!
    unless SUPPORTED_DISTROS.key?(@distro)
      raise ArgumentError, "Unsupported distro: #{@distro}. Supported: #{SUPPORTED_DISTROS.keys.join(', ')}"
    end
  end

  def load_dependency_aliases
    @alias_map = {}

    system_packages_dir = File.join(@data_dir, 'system_packages')
    return unless Dir.exist?(system_packages_dir)

    Dir.glob(File.join(system_packages_dir, '*', 'aliases.json')).each do |aliases_file|
      begin
        data = JSON.parse(File.read(aliases_file))
        canonical = data['canonical']
        aliases = data['aliases'] || []

        aliases.each do |alias_name|
          @alias_map[alias_name] = canonical
        end
      rescue JSON::ParserError => e
        puts "Warning: Failed to parse #{aliases_file}: #{e.message}"
      end
    end

    puts "Loaded #{@alias_map.size} dependency aliases" if @alias_map.any?
  end

  def resolve_dependency(dep_name)
    @alias_map[dep_name] || dep_name
  end

  def load_gem_data
    gem_data_dir = File.join(@data_dir, 'rubygems', @gem_name)

    unless Dir.exist?(gem_data_dir)
      puts "Warning: No dependency data found for #{@gem_name}"
      @dependencies = []
      @extra_gem_dependencies = []
      @require_path = nil
      return
    end

    # Find the version-specific JSON file or use the latest
    if @version
      version_file = File.join(gem_data_dir, "#{@version}.json")
      unless File.exist?(version_file)
        raise "Version #{@version} not found for #{@gem_name}"
      end
      data = JSON.parse(File.read(version_file))
    else
      # Find the latest version file
      json_files = Dir.glob(File.join(gem_data_dir, '*.json'))
      if json_files.empty?
        @dependencies = []
        @extra_gem_dependencies = []
        @require_path = nil
        return
      end

      latest_file = json_files.max_by { |f| Gem::Version.new(File.basename(f, '.json')) rescue File.basename(f, '.json') }
      data = JSON.parse(File.read(latest_file))
      @version ||= data['version']
    end

    raw_dependencies = data['dependencies'] || []
    @dependencies = raw_dependencies.map { |dep| resolve_dependency(dep) }.uniq
    @require_path = data['require_path']
    @extra_gem_dependencies = data['test_extra_runtime_dependencies'] || []

    unless @dependencies.empty?
      puts "Found dependencies: #{raw_dependencies.join(', ')}"
      if raw_dependencies != @dependencies
        puts "Resolved to: #{@dependencies.join(', ')}"
      end
    end

    puts "Extra gem dependencies: #{@extra_gem_dependencies.join(', ')}" unless @extra_gem_dependencies.empty?
    puts "Using custom require path: #{@require_path}" if @require_path
  end

  def create_dockerfile(tmpdir)
    dockerfile = File.join(tmpdir, 'Dockerfile')

    content = <<~DOCKERFILE
      FROM #{SUPPORTED_DISTROS[@distro]}

      # Install Ruby and build tools
      RUN #{RUBY_INSTALL_COMMANDS[@distro]}

      # Install system dependencies
    DOCKERFILE

    # Add install scripts for each dependency
    installed_deps = []
    missing_deps = []

    @dependencies.each do |dep|
      install_script_path = File.join(@data_dir, 'system_packages', dep, @distro, 'install.sh')

      if File.exist?(install_script_path)
        script_content = File.read(install_script_path)
        # Copy the install script into the container
        local_script = File.join(tmpdir, "install_#{dep}.sh")
        File.write(local_script, script_content)

        content += "COPY install_#{dep}.sh /tmp/\n"
        content += "RUN chmod +x /tmp/install_#{dep}.sh && /tmp/install_#{dep}.sh\n"
        installed_deps << dep
      else
        missing_deps << dep
      end
    end

    if missing_deps.any?
      puts "\nWarning: No install scripts found for: #{missing_deps.join(', ')}"
      puts "The gem installation may fail if these are required dependencies."
    end

    puts "\nInstalling system dependencies: #{installed_deps.join(', ')}" if installed_deps.any?

    # Install extra gem dependencies if needed
    if @extra_gem_dependencies.any?
      content += "\n# Install extra gem dependencies\n"
      content += "RUN gem install #{@extra_gem_dependencies.join(' ')} --no-document\n"
      puts "Installing extra gem dependencies: #{@extra_gem_dependencies.join(', ')}"
    end

    # Add the gem install command
    gem_spec = @version ? "#{@gem_name}:#{@version}" : @gem_name
    content += "\n# Install the gem\n"
    content += "RUN gem install #{gem_spec} --no-document\n"

    # Verify installation
    content += "\n# Verify installation\n"
    content += "RUN ruby -e \"require '#{gem_name_for_require}'; puts 'Successfully loaded #{@gem_name}'\"\n"

    File.write(dockerfile, content)

    puts "\nDockerfile:"
    puts "-" * 80
    puts content
    puts "-" * 80

    dockerfile
  end

  def gem_name_for_require
    # Use custom require_path from JSON if specified
    return @require_path if @require_path

    # For gems without dependency data, try common patterns
    # Many Ruby gems use underscores instead of dashes (e.g., 'ruby-xz' -> 'xz')
    # First try: remove common prefixes and convert to underscore
    simplified = @gem_name.sub(/^ruby[-_]/, '').tr('-', '_')

    # If the simplified name is different, use it; otherwise use the original with underscores
    simplified != @gem_name ? simplified : @gem_name.tr('-', '_')
  end

  def build_and_run_container(tmpdir, dockerfile_path)
    image_name = "rubygem-test-#{@gem_name}-#{@distro}".downcase.tr('_', '-')

    # Build the Docker image
    puts "\nBuilding Docker image..."
    build_cmd = "docker build -t #{image_name} -f #{dockerfile_path} #{tmpdir}"

    success = system(build_cmd)

    # Clean up the image
    if success
      puts "\nCleaning up Docker image..."
      system("docker rmi #{image_name} 2>/dev/null")
    end

    success
  end
end

# CLI interface
if __FILE__ == $PROGRAM_NAME
  if ARGV.empty? || ARGV.include?('--help') || ARGV.include?('-h')
    puts "Usage: #{$PROGRAM_NAME} GEM_NAME [VERSION] [--distro DISTRO]"
    puts ""
    puts "Arguments:"
    puts "  GEM_NAME    Name of the Ruby gem to test"
    puts "  VERSION     Specific version to test (optional)"
    puts ""
    puts "Options:"
    puts "  --distro    Linux distribution to test on (default: debian)"
    puts "              Supported: #{RubyGemTester::SUPPORTED_DISTROS.keys.join(', ')}"
    puts ""
    puts "Examples:"
    puts "  #{$PROGRAM_NAME} pg"
    puts "  #{$PROGRAM_NAME} pg 1.6.2"
    puts "  #{$PROGRAM_NAME} nokogiri --distro alpine"
    puts "  #{$PROGRAM_NAME} nokogiri 1.15.4 --distro ubuntu"
    exit 0
  end

  gem_name = ARGV[0]
  version = nil
  distro = 'debian'

  # Parse arguments
  i = 1
  while i < ARGV.length
    case ARGV[i]
    when '--distro'
      distro = ARGV[i + 1]
      i += 2
    else
      # Assume it's a version if it looks like one
      if ARGV[i] =~ /^\d+\.\d+/
        version = ARGV[i]
      end
      i += 1
    end
  end

  begin
    tester = RubyGemTester.new(gem_name, version: version, distro: distro)
    exit(tester.test ? 0 : 1)
  rescue => e
    puts "Error: #{e.message}"
    puts e.backtrace if ENV['DEBUG']
    exit 1
  end
end
