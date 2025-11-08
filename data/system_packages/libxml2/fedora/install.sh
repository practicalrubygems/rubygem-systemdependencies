#!/bin/bash
set -e

dnf install -y \
  libxml2-devel

dnf clean all
