#!/bin/bash
set -e

apt-get update -qq
apt-get install -y --no-install-recommends cmake
apt-get clean
rm -rf /var/lib/apt/lists/*
