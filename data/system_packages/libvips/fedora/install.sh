#!/bin/bash
set -e

dnf install -y \
  vips-devel

dnf clean all
