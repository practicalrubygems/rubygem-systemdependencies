#!/bin/bash
set -e

dnf install -y \
  ImageMagick \
  ImageMagick-devel

dnf clean all
