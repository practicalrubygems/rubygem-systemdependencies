#!/bin/bash
set -e

dnf install -y libpcap-devel
dnf clean all
