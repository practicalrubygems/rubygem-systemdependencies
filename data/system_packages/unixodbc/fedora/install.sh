#!/bin/bash
set -e

dnf install -y \
  unixODBC-devel

dnf clean all
