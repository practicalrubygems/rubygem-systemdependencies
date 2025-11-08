#!/bin/bash
set -e

dnf install -y \
  valkey

dnf clean all
