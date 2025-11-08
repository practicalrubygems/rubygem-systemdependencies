#!/bin/bash
set -e

dnf install -y \
  mysql-devel

dnf clean all
