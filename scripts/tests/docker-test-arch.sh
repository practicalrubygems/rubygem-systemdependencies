#!/bin/bash
# Run Arch Linux tests in Docker container
# Usage: ./docker-test-arch.sh [package_category]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CATEGORY="${1:-}"

echo "Running Arch Linux tests in Docker container..."

docker run --rm \
  -v "$PROJECT_ROOT:/repo:ro" \
  -w /repo \
  archlinux:latest \
  bash -c "pacman -Sy --noconfirm && bash /repo/scripts/tests/test-arch.sh $CATEGORY"
