#!/bin/bash
# Run all distribution tests in Docker containers
# Usage: ./docker-run-all-tests.sh [category]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATEGORY="${1:-}"

echo "======================================"
echo "Docker-based Test Suite"
echo "======================================"
echo ""

if [ -n "$CATEGORY" ]; then
    echo "Testing category: $CATEGORY"
    echo ""
fi

total_failed=0
total_passed=0

# Test Debian
echo "========================================"
if bash "$SCRIPT_DIR/docker-test-debian.sh" "$CATEGORY"; then
    total_passed=$((total_passed + 1))
    echo "✅ Debian tests passed"
else
    total_failed=$((total_failed + 1))
    echo "❌ Debian tests failed"
fi
echo ""

# Test Ubuntu
echo "========================================"
if bash "$SCRIPT_DIR/docker-test-ubuntu.sh" "$CATEGORY"; then
    total_passed=$((total_passed + 1))
    echo "✅ Ubuntu tests passed"
else
    total_failed=$((total_failed + 1))
    echo "❌ Ubuntu tests failed"
fi
echo ""

# Test Alpine
echo "========================================"
if bash "$SCRIPT_DIR/docker-test-alpine.sh" "$CATEGORY"; then
    total_passed=$((total_passed + 1))
    echo "✅ Alpine tests passed"
else
    total_failed=$((total_failed + 1))
    echo "❌ Alpine tests failed"
fi
echo ""

# Test Fedora
echo "========================================"
if bash "$SCRIPT_DIR/docker-test-fedora.sh" "$CATEGORY"; then
    total_passed=$((total_passed + 1))
    echo "✅ Fedora tests passed"
else
    total_failed=$((total_failed + 1))
    echo "❌ Fedora tests failed"
fi
echo ""

# Test Arch
echo "========================================"
if bash "$SCRIPT_DIR/docker-test-arch.sh" "$CATEGORY"; then
    total_passed=$((total_passed + 1))
    echo "✅ Arch tests passed"
else
    total_failed=$((total_failed + 1))
    echo "❌ Arch tests failed"
fi
echo ""

# Test nixpkgs (local)
echo "========================================"
echo "Running nixpkgs tests locally..."
if bash "$SCRIPT_DIR/test-nixpkgs.sh" "$CATEGORY"; then
    total_passed=$((total_passed + 1))
    echo "✅ nixpkgs tests passed"
else
    total_failed=$((total_failed + 1))
    echo "❌ nixpkgs tests failed"
fi
echo ""

# Test devenv (local)
echo "========================================"
echo "Running devenv tests locally..."
if bash "$SCRIPT_DIR/test-devenv.sh" "$CATEGORY"; then
    total_passed=$((total_passed + 1))
    echo "✅ devenv tests passed"
else
    total_failed=$((total_failed + 1))
    echo "❌ devenv tests failed"
fi
echo ""

echo "========================================"
echo "Final Results"
echo "========================================"
echo "Passed: $total_passed distributions"
echo "Failed: $total_failed distributions"
echo ""

if [ $total_failed -gt 0 ]; then
    echo "❌ Some tests failed"
    exit 1
else
    echo "✅ All tests passed!"
    exit 0
fi
