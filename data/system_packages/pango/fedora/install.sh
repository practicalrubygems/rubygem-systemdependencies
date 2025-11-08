#!/bin/bash
set -e
dnf install -y glib2-devel pango-devel gobject-introspection-devel
dnf clean all
