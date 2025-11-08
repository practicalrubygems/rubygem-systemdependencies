#!/bin/bash
set -e

dnf install -y \
  zlib-ng-compat-devel

dnf clean all
