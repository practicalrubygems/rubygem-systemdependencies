# System Package Testing Framework

This directory contains test scripts for validating system package definitions across all supported distributions.

## Test Scripts

Each distribution has its own test script:

- `test-debian.sh` - Tests Debian package definitions
- `test-ubuntu.sh` - Tests Ubuntu package definitions
- `test-alpine.sh` - Tests Alpine package definitions
- `test-fedora.sh` - Tests Fedora package definitions
- `test-arch.sh` - Tests Arch Linux package definitions
- `test-devenv.sh` - Tests devenv.nix definitions
- `test-nixpkgs.sh` - Tests nixpkgs shell.nix definitions

## What Tests Do

Each test script performs two main checks:

### A) Package Existence Check
Verifies that all packages listed in `packages.txt` exist in the distribution's package repository:
- **Debian/Ubuntu**: Uses `apt-cache show`
- **Alpine**: Uses `apk search`
- **Fedora**: Uses `dnf info`
- **Arch**: Uses `pacman -Si`
- **devenv/nixpkgs**: Uses `nix-instantiate` to verify nixpkgs attributes

### B) Installation Script Validation
Validates that installation scripts are correct and can run:
- **Debian/Ubuntu/Alpine/Fedora/Arch**: Checks `install.sh` syntax with bash/sh `-n` flag
- **devenv**: Validates `devenv.nix` Nix syntax
- **nixpkgs**: Validates and instantiates `shell.nix`

## Usage

### Test a Single Category on One Distribution

```bash
# Test postgresql on Debian
./test-debian.sh postgresql

# Test libxml2 on Alpine
./test-alpine.sh libxml2

# Test nodejs on nixpkgs
./test-nixpkgs.sh nodejs
```

### Test All Categories on One Distribution

```bash
# Test all categories on Ubuntu
./test-ubuntu.sh

# Test all categories on devenv
./test-devenv.sh
```

### Test One Category Across All Distributions

```bash
# Test postgresql on all distributions
./run-all-tests.sh postgresql
```

### Test Everything

```bash
# Test all categories on all distributions
./run-all-tests.sh
```

## Requirements

To run tests, you need the appropriate package manager installed:

- **Debian tests**: Requires `apt-cache` (Debian/Ubuntu systems)
- **Ubuntu tests**: Requires `apt-cache` (Debian/Ubuntu systems)
- **Alpine tests**: Requires `apk` (Alpine Linux)
- **Fedora tests**: Requires `dnf` (Fedora/RHEL systems)
- **Arch tests**: Requires `pacman` (Arch Linux)
- **devenv tests**: Requires `nix-instantiate` and optionally `devenv`
- **nixpkgs tests**: Requires `nix-instantiate` and `nix-shell`

## Running Tests in Docker

For distributions you don't have installed, use Docker:

```bash
# Test on Debian
docker run -v $(pwd):/repo -w /repo debian:bookworm bash scripts/tests/test-debian.sh

# Test on Alpine
docker run -v $(pwd):/repo -w /repo alpine:latest sh scripts/tests/test-alpine.sh

# Test on Fedora
docker run -v $(pwd):/repo -w /repo fedora:latest bash scripts/tests/test-fedora.sh

# Test on Arch
docker run -v $(pwd):/repo -w /repo archlinux:latest bash scripts/tests/test-arch.sh
```

## Exit Codes

- `0`: All tests passed
- `1`: One or more tests failed

## Example Output

```
Testing postgresql for debian...
  Checking package availability...
    ✓ Package 'postgresql-client' exists
    ✓ Package 'libpq-dev' exists
  Testing install script...
    ✓ Install script syntax valid
  ✅ All tests passed for postgresql
```

## CI/CD Integration

These tests can be integrated into CI/CD pipelines:

```yaml
# GitHub Actions example
- name: Test Debian Packages
  run: |
    docker run -v $(pwd):/repo -w /repo debian:bookworm \
      bash scripts/tests/test-debian.sh

- name: Test All Distributions
  run: |
    scripts/tests/run-all-tests.sh
```

## Adding New Tests

To add a new distribution:

1. Create `test-<distro>.sh` in this directory
2. Implement `test_package_category()` function
3. Add package existence check (Test A)
4. Add installation script validation (Test B)
5. Make the script executable: `chmod +x test-<distro>.sh`
6. The `run-all-tests.sh` script will automatically pick it up
