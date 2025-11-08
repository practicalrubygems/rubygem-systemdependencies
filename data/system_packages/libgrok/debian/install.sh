#!/bin/bash
set -e

# Install build and runtime dependencies for libgrok
apt-get update -qq
apt-get install -y --no-install-recommends \
    bison \
    flex \
    gperf \
    libevent-dev \
    libpcre3-dev \
    libtokyocabinet-dev \
    libtirpc-dev \
    git \
    ca-certificates

# Clone and build libgrok from source
cd /tmp
git clone --depth 1 https://github.com/jordansissel/grok.git
cd grok

# Set compiler flags to find tirpc headers
export CFLAGS="-I/usr/include/tirpc"
export LDFLAGS="-ltirpc"

make
make install

# Update library cache
ldconfig

# Cleanup
cd /
rm -rf /tmp/grok
apt-get remove -y git ca-certificates
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*
