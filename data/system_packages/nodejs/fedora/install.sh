#!/bin/bash
set -e

dnf install -y \
  nodejs \
  nodejs-npm

dnf clean all
