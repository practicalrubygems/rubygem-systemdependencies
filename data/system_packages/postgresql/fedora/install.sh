#!/bin/bash
set -e

dnf install -y \
  postgresql \
  libpq-devel

dnf clean all
