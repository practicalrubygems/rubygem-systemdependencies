#!/bin/bash
set -e

apt-get update -qq
apt-get install -y --no-install-recommends \
  redis-server

apt-get clean
rm -rf /var/lib/apt/lists/*
