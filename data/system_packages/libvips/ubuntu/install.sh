#!/bin/bash
set -e

apt-get update -qq
apt-get install -y --no-install-recommends \
  libvips-dev

apt-get clean
rm -rf /var/lib/apt/lists/*
