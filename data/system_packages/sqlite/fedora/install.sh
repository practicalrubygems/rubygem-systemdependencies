#!/bin/bash
set -e

dnf install -y \
  sqlite-devel

dnf clean all
