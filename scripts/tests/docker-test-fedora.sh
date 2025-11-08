#!/bin/bash
# Run Fedora tests in Docker container
# Usage: ./docker-test-fedora.sh [package_category]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CATEGORY="${1:-}"

echo "Running Fedora tests in Docker container..."

docker run --rm \
  -v "$PROJECT_ROOT:/repo:ro" \
  -w /repo \
  fedora:latest \
  bash -c "bash /repo/scripts/tests/test-fedora.sh $CATEGORY"
