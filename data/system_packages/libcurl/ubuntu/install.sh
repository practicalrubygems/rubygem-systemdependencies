#!/bin/bash
set -e

apt-get update -qq
apt-get install -y --no-install-recommends \
  libcurl4-openssl-dev

apt-get clean
rm -rf /var/lib/apt/lists/*
