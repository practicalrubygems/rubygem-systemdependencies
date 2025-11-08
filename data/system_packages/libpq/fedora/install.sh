#!/bin/bash
set -e

dnf install -y \
  libpq-devel

dnf clean all
