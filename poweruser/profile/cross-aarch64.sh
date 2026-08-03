#!/usr/bin/env bash

# ARM64 cross-compilation profile
# Target: aarch64 (ARM 64-bit, little-endian)
# Requires: ARMtix toolchain or equivalent cross-compiler

ARTIX_CFLAGS="-O2 -march=armv8-a -mtune=generic -pipe"
ARTIX_CXXFLAGS="${ARTIX_CFLAGS}"
ARTIX_LDFLAGS="-Wl,-O1,--sort-common,--as-needed"
ARTIX_MAKEFLAGS="$(nproc)"

CROSS_COMPILE="aarch64-unknown-linux-gnu-"
ARCH="arm64"
TARGET_ARCH="aarch64"

GLOBAL_FEATURES=""