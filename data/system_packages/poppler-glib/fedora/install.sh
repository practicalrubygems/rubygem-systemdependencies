#!/bin/bash
set -e

dnf install -y pkgconfig(poppler-glib)
dnf clean all
