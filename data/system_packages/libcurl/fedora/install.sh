#!/bin/bash
set -e

dnf install -y \
  libcurl-devel

dnf clean all
