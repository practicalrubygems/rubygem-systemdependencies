#!/bin/bash
set -e
apt-get update -qq
apt-get install -y --no-install-recommends libbz2-dev
apt-get clean
rm -rf /var/lib/apt/lists/*
