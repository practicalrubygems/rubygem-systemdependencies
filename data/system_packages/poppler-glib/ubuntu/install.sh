#!/bin/bash
set -e

apt-get update -qq
apt-get install -y --no-install-recommends libpoppler-glib-dev
apt-get clean
rm -rf /var/lib/apt/lists/*
