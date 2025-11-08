#!/bin/bash
set -e

apt-get update -qq
apt-get install -y --no-install-recommends libgit2-dev pkg-config libssl-dev
apt-get clean
rm -rf /var/lib/apt/lists/*
