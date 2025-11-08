#!/bin/bash
set -e

dnf install -y libgit2-devel pkgconfig openssl-devel
dnf clean all
