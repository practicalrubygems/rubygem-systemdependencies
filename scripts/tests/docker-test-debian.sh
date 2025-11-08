#!/bin/bash
# Run Debian tests in Docker container
# Usage: ./docker-test-debian.sh [package_category]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CATEGORY="${1:-}"

echo "Running Debian tests in Docker container..."

docker run --rm \
  -v "$PROJECT_ROOT:/repo:ro" \
  -w /repo \
  debian:bookworm \
  bash -c "apt-get update -qq && bash /repo/scripts/tests/test-debian.sh $CATEGORY"
