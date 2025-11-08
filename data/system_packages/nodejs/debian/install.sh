#!/bin/bash
set -e

apt-get update -qq
apt-get install -y --no-install-recommends \
  nodejs \
  npm

apt-get clean
rm -rf /var/lib/apt/lists/*
