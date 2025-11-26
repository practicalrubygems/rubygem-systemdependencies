# RubyGem System Dependencies

Nearly every Ruby developer encounters this problem: you run `bundle install`, and the installation fails with cryptic compiler errors about missing header files. The gem needs libxml2, libxslt, or some other system library — but which packages provide these on your distribution? And how do you automate this in CI/CD pipelines where manual intervention isn't an option?

This project provides a centralized, machine-readable database that maps RubyGems to their system package dependencies across multiple Linux distributions. We track exactly which system packages (libxml2-dev, postgresql-dev, etc.) are required to install each gem, with distribution-specific installation scripts for automated environments.

Before we get into the details, though, it's worth understanding why this problem exists. RubyGems with native extensions — gems that compile C code during installation — rely on system libraries that aren't managed by RubyGems itself. The gem author documents these requirements (if you're lucky), but translating "needs PostgreSQL development headers" into the right apt, apk, or dnf command varies by distribution. This project solves that translation problem.

## What This Project Provides

We maintain two types of data:

- **Gem Dependency Mappings** (`data/rubygems/`): For each gem version, a JSON file listing required system package categories
- **Distribution Installation Scripts** (`data/system_packages/`): For each system package, shell scripts that install it on Debian, Ubuntu, Alpine, Fedora, and Arch

The data is structured to support automation. You can query "what does nokogiri 1.13.0 need?" and get back `["libxml2", "libxslt", "zlib"]`, then execute the appropriate installation scripts for your distribution.

## When You'd Use This

This project addresses several scenarios where gem installation dependencies become problematic:

**CI/CD Pipelines**: Your GitHub Actions workflow needs to install system dependencies before running `bundle install`. You can use this project's data to automate that step rather than maintaining distribution-specific dependency lists in your workflow files.

**Container Images**: You're building a Docker image for a Rails application. Instead of manually determining which Alpine packages to install, you can query this database and generate the appropriate `apk add` commands.

**Development Environment Setup**: You're creating setup scripts for new developers on your team. Rather than documenting "install PostgreSQL, Redis, and ImageMagick" with manual instructions, you can automate the process using the installation scripts here.

**Cross-Distribution Testing**: You need to verify your gem works across Debian, Ubuntu, and Alpine. This project provides consistent installation procedures for each distribution.

## Quick Start

### Querying Gem Dependencies

We organize the data in two directories. For gem dependencies:

```bash
# View dependencies for nokogiri version 1.13.0
cat data/rubygems/nokogiri/1.13.0.json
```

You'll see something like this:

```json
{
  "gem": "nokogiri",
  "version": "1.13.0",
  "dependencies": ["libxml2", "libxslt", "zlib"],
  "generated_at": "2025-11-08T15:56:25Z",
  "notes": "Dependencies detected from README and extconf.rb"
}
```

For system package installation:

```bash
# View the installation script for libxml2 on Debian
cat data/system_packages/libxml2/debian/install.sh
```

## Supported Distributions

We currently provide installation scripts for these distributions:

- **Debian**: 11 (Bullseye), 12 (Bookworm)
- **Ubuntu**: 20.04 (Focal), 22.04 (Jammy), 24.04 (Noble)
- **Alpine**: 3.17, 3.18, 3.19
- **Fedora**: 38, 39 (planned)
- **Arch Linux**: (planned)

Distribution support expands as we add more system packages. If you need support for a specific distribution, see the Contributing section below.

## Maintenance and Support

This repository is maintained by Durable Programming LLC. We add new gems and update existing dependency data as needed, though we prioritize popular gems and those with active user requests.

## License

MIT License - See [LICENSE](LICENSE) for details

## Related Projects

- [apt-gem](https://github.com/dcu/gem2deb) - Convert RubyGems to deb packages
- [fpm](https://github.com/jordansissel/fpm) - Convert RubyGems to deb, rpm, and other packages
- [dockerizing-ruby](https://github.com/docker-library/ruby) - Official Ruby Docker images
- [bundler](https://bundler.io/) - Ruby dependency management

## Support

- **Documentation**: This README and inline documentation
- **Issues**: [GitHub Issues](https://github.com/durableprogramming/rubygem-systemdependencies/issues)
- **Commercial Support**: commercial@durableprogramming.com

## About Durable Programming

Durable Programming LLC creates sustainable software solutions focused on long-term maintainability, reliability, and practical problem-solving. We believe in:

- Building tools that solve real-world problems
- Creating software that stands the test of time
- Contributing to open source communities
- Transparent, honest communication
- Quality over quantity

Learn more at [durableprogramming.com](https://durableprogramming.com)
