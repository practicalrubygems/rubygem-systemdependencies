#!/bin/bash
set -e

dnf install -y \
  libxslt-devel

dnf clean all
