#!/bin/bash
# Run Alpine tests in Docker container
# Usage: ./docker-test-alpine.sh [package_category]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CATEGORY="${1:-}"

echo "Running Alpine tests in Docker container..."

docker run --rm \
  -v "$PROJECT_ROOT:/repo:ro" \
  -w /repo \
  alpine:latest \
  sh -c "apk update -q && sh /repo/scripts/tests/test-alpine.sh $CATEGORY"
