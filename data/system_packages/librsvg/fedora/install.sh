#!/bin/bash
set -e
dnf install -y glib2-devel librsvg2-devel gobject-introspection-devel
dnf clean all
