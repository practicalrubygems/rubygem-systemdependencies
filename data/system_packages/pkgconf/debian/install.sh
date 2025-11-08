#!/bin/bash
set -e

apt-get update -qq
apt-get install -y --no-install-recommends pkg-config
apt-get clean
rm -rf /var/lib/apt/lists/*
