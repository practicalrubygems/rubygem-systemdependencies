#!/bin/sh
# Test all Alpine package install scripts
# Usage: ./test-alpine.sh [package_category]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CATEGORY="${1:-}"
DISTRO="alpine"

echo "Testing $DISTRO package installation scripts..."

# Count total and failed
total=0
failed=0
failed_packages=""

# Get list of packages to test
if [ -n "$CATEGORY" ]; then
    packages="$CATEGORY"
else
    packages=$(ls -1 "$PROJECT_ROOT/data/system_packages/")
fi

for package in $packages; do
    install_script="$PROJECT_ROOT/data/system_packages/$package/$DISTRO/install.sh"

    # Skip if install script doesn't exist
    if [ ! -f "$install_script" ]; then
        echo "⚠️  Skipping $package (no $DISTRO install script)"
        continue
    fi

    total=$((total + 1))
    printf "Testing %s... " "$package"

    # Run the install script
    if sh "$install_script" > /dev/null 2>&1; then
        echo "✅"
    else
        echo "❌"
        failed=$((failed + 1))
        failed_packages="$failed_packages $package"
    fi
done

echo ""
echo "======================================"
echo "Results: $((total - failed))/$total passed"
echo "======================================"

if [ $failed -gt 0 ]; then
    echo "Failed packages:$failed_packages"
    exit 1
else
    echo "All tests passed!"
    exit 0
fi
