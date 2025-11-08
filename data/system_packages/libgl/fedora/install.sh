#!/bin/bash
set -e
dnf install -y mesa-libGL-devel
dnf clean all
