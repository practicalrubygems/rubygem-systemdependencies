#!/bin/bash
# Run Ubuntu tests in Docker container
# Usage: ./docker-test-ubuntu.sh [package_category]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CATEGORY="${1:-}"

echo "Running Ubuntu tests in Docker container..."

docker run --rm \
  -v "$PROJECT_ROOT:/repo:ro" \
  -w /repo \
  ubuntu:24.04 \
  bash -c "apt-get update -qq && bash /repo/scripts/tests/test-ubuntu.sh $CATEGORY"
