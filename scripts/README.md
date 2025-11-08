# Dependency Generation Scripts

Automated tools for generating system dependency data for RubyGems through pattern matching and static analysis.

## Overview

These scripts analyze gem documentation (README) and build scripts (extconf.rb) to automatically detect system-level dependencies. They generate JSON files in the `data/rubygems/` directory that map gems to system package categories.

**Key Features:**
- Non-destructive: Won't overwrite manually-curated data
- Pattern matching: Uses configurable rules to identify dependencies
- Multiple sources: Analyzes README, extconf.rb, and gem metadata
- Extensible: Easy to add new patterns and detection methods

## Quick Start

### Process a Single Gem

```bash
# Generate dependencies for latest version
ruby scripts/generate_gem_dependencies.rb nokogiri

# Generate dependencies for specific version
ruby scripts/generate_gem_dependencies.rb nokogiri 1.13.0

# Force overwrite existing data
ruby scripts/generate_gem_dependencies.rb nokogiri --force

# Verbose output for debugging
ruby scripts/generate_gem_dependencies.rb nokogiri --verbose

# Dry run (show what would be done)
ruby scripts/generate_gem_dependencies.rb nokogiri --dry-run
```

### Process Multiple Gems

```bash
# Process gems from a list file
ruby scripts/generate_gem_dependencies.rb --list scripts/examples/popular_gems.txt

# With verbose output
ruby scripts/generate_gem_dependencies.rb --list scripts/examples/popular_gems.txt --verbose
```

## Architecture

### Main Script: `generate_gem_dependencies.rb`

Orchestrates the dependency extraction process:
1. Fetches gem metadata and downloads gem files
2. Extracts README and extconf.rb
3. Parses files for dependency hints
4. Matches hints to system package categories
5. Generates JSON output

### Module: `lib/gem_fetcher.rb`

Handles gem downloading and extraction:
- Queries RubyGems.org API for gem information
- Downloads .gem files with caching
- Extracts README and extconf.rb from gem archives
- Implements retry logic for network requests

### Module: `lib/readme_parser.rb`

Parses README files for dependency hints:
- Pattern matching for library mentions
- Installation command detection
- Package name extraction
- False positive filtering

**Patterns detected:**
- "requires libxml2"
- "apt-get install postgresql-dev"
- "Install PostgreSQL"
- Library names: libxml2, libpq, libcurl

### Module: `lib/extconf_parser.rb`

Parses extconf.rb for library requirements:
- `have_library('libname')` calls
- `find_library('libname')` calls
- `pkg_config('package')` calls
- Header file checks: `have_header('header.h')`
- Maps headers to libraries (e.g., libpq-fe.h → postgresql)

### Module: `lib/dependency_matcher.rb`

Matches dependency hints to system packages:
- Loads rules from `config/dependency_patterns.yml`
- Normalizes library names (libpq → postgresql)
- Handles aliases and variations
- Pattern-based matching with regular expressions

### Module: `lib/json_generator.rb`

Generates standardized JSON output:
- Creates structured gem dependency data
- Includes metadata (generation time, confidence level)
- Pretty-prints JSON for readability
- Adds processing notes

### Configuration: `config/dependency_patterns.yml`

Defines mapping rules:
- **Direct mappings**: String-to-category mappings
- **Patterns**: Regex-based matching rules
- **Gem overrides**: Known dependencies for specific gems

## Output Format

Generated JSON files follow this structure:

```json
{
  "gem": "nokogiri",
  "version": "1.13.0",
  "dependencies": [
    "libxml2",
    "libxslt",
    "zlib"
  ],
  "generated_at": "2024-11-07T14:30:00Z",
  "generator": "rubygem-systemdependencies",
  "confidence": "high",
  "notes": "Dependencies detected from README and extconf.rb. Found 3 dependency hints: libxml2, libxslt, zlib"
}
```

**Confidence Levels:**
- `unknown`: No dependencies detected (0)
- `low`: 1-2 dependencies detected
- `medium`: 3-5 dependencies detected
- `high`: 6+ dependencies detected

## Configuration

### Adding New Patterns

Edit `config/dependency_patterns.yml`:

```yaml
mappings:
  # Add direct string mapping
  newlib: newlib

patterns:
  # Add regex pattern
  - pattern: '\bnewlib'
    category: newlib

gem_overrides:
  # Add gem-specific override
  somegem:
    - newlib
    - otherdep
```

### Pattern Matching Priority

1. **Gem-specific overrides** (highest priority)
2. **Direct mappings** from hints to categories
3. **Pattern-based matching** using regular expressions
4. **Fallback** to hint as-is if it looks like a library name

## Examples

### Example: Processing nokogiri

```bash
$ ruby scripts/generate_gem_dependencies.rb nokogiri --verbose
INFO -- : Processing nokogiri...
INFO -- : Analyzing nokogiri 1.13.0...
DEBUG -- : Downloading nokogiri 1.13.0...
DEBUG -- : Downloaded nokogiri 1.13.0 (8543829 bytes)
DEBUG -- : Found README: README.md
DEBUG -- : Found extconf.rb: ext/nokogiri/extconf.rb
DEBUG -- : Parsing README (45382 bytes)...
DEBUG -- : Found 3 dependency hints in README: libxml2, libxslt, zlib
DEBUG -- : Parsing extconf.rb (2847 bytes)...
DEBUG -- : Found 3 dependencies in extconf.rb: libxml2, libxslt, zlib
DEBUG -- : Matching 3 hints to system packages...
DEBUG -- : Matched to 3 system packages: libxml2, libxslt, zlib
INFO -- : ✓ Generated dependency data for nokogiri 1.13.0
```

Output file: `data/rubygems/nokogiri/1.13.0.json`

### Example: Batch Processing

```bash
$ ruby scripts/generate_gem_dependencies.rb --list scripts/examples/popular_gems.txt
INFO -- : Processing pg...
INFO -- : ✓ Generated dependency data for pg 1.5.4
INFO -- : Processing mysql2...
INFO -- : ✓ Generated dependency data for mysql2 0.5.5
INFO -- : Processing sqlite3...
INFO -- : ✓ Generated dependency data for sqlite3 1.6.9
...
Results: 25 succeeded, 0 failed
```

## Maintenance

### Updating Patterns

When adding support for new gems:

1. Test pattern matching on actual gem files
2. Verify system package categories exist in `data/system_packages/`
3. Add mappings for all common variations
4. Test with both README and extconf.rb sources
5. Validate generated JSON output

### Handling False Positives

The parsers include filters for common false positives:
- Generic words: "the", "and", "for", "require"
- Ruby-specific terms: "ruby", "gem", "rails", "bundler"
- Documentation terms: "readme", "example", "documentation"

Add new filters in:
- `lib/readme_parser.rb`: `false_positive?` method
- `lib/extconf_parser.rb`: validation methods

### Cache Management

Downloaded gems are cached in `/tmp/gem_dependency_cache/`:

```bash
# Clear cache
rm -rf /tmp/gem_dependency_cache/

# Set custom cache directory
export GEM_CACHE_DIR=/path/to/cache
```

## Limitations

**Current limitations:**
- Only analyzes gems available on RubyGems.org
- Pattern matching may miss non-standard dependency documentation
- Cannot detect runtime-only dependencies (without C extensions)
- Requires manual verification for complex dependency chains

**Manual review recommended for:**
- Gems with unusual documentation formats
- Gems with optional dependencies
- Gems with platform-specific requirements
- Gems with version-specific dependency changes

## Contributing

### Adding Detection Patterns

To improve detection accuracy:

1. Find gems with undetected dependencies
2. Analyze their README and extconf.rb
3. Add patterns to `config/dependency_patterns.yml`
4. Test pattern on multiple gems
5. Submit pull request with examples

### Reporting Issues

Report detection issues with:
- Gem name and version
- Expected dependencies
- Links to gem documentation
- Sample README/extconf.rb content

## Development

### Running Tests

```bash
# Run the test suite (when implemented)
rake test

# Run with specific gems for testing
ruby scripts/generate_gem_dependencies.rb nokogiri --dry-run --verbose
```

### Debugging

Use verbose and dry-run modes:

```bash
# See all debug output without writing files
ruby scripts/generate_gem_dependencies.rb nokogiri --verbose --dry-run
```

Check logs for:
- Pattern matching results
- Dependency hint extraction
- Category mapping decisions

## Related Documentation

- [Main Project README](../README.md) - Overview and usage
- [Dependency Patterns Config](config/dependency_patterns.yml) - Pattern rules
- [Popular Gems List](examples/popular_gems.txt) - Example gem list

## License

MIT License - See [LICENSE](../LICENSE) for details
