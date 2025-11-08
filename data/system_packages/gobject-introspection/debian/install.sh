#!/bin/bash
set -e
apt-get update -qq
apt-get install -y --no-install-recommends libgirepository1.0-dev
apt-get clean
rm -rf /var/lib/apt/lists/*
