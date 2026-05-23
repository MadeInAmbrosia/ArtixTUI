#!/usr/bin/env bash
pkgname=artix-coreutils
pkgver=1.0.0
pkgrel=1
desc="ArtixTUI minimal coreutils — debloated, source-built"
url="https://github.com/realvolk/ArtixTUI"

# This recipe builds a minimal set of essential tools from multiple sources.
# It's not a full coreutils replacement, just the most-used binaries,
# compiled with -Os and stripped for minimal size.

sources=(
  "https://busybox.net/downloads/busybox-1.36.1.tar.bz2|SKIP|busybox-1.36.1.tar.bz2"
)

depends=()
makedepends=(base-devel)

feature_flags=(
  include-shell
  include-network
  include-filesystem-tools
)

prepare() {
  cd "${BUILD_DIR}"
  tar xf "${SOURCES_DIR}/busybox-1.36.1.tar.bz2"
  mv "busybox-1.36.1" src
}

configure() {
  cd "${BUILD_DIR}/src"
  make allnoconfig

  for applet in cat cp mv rm ln ls mkdir rmdir chmod chown chgrp \
                echo printf yes false true test sleep sync \
                grep sed awk cut head tail sort uniq wc tr \
                mount umount df du find xargs tar gzip \
                basename dirname realpath readlink stat mktemp \
                id whoami groups passwd su \
                kill pidof ps free uptime \
                clear reset tty stty; do
    sed -i "s/^# CONFIG_${applet^^} is not set/CONFIG_${applet^^}=y/" .config
  done

  for feat in "${selected_features[@]}"; do
    case "${feat}" in
      include-shell)
        sed -i 's/^# CONFIG_ASH is not set/CONFIG_ASH=y/' .config
        sed -i 's/^# CONFIG_SH_IS_ASH is not set/CONFIG_SH_IS_ASH=y/' .config
        ;;
      include-network)
        sed -i 's/^# CONFIG_PING is not set/CONFIG_PING=y/' .config
        sed -i 's/^# CONFIG_WGET is not set/CONFIG_WGET=y/' .config
        ;;
      include-filesystem-tools)
        sed -i 's/^# CONFIG_FSCK is not set/CONFIG_FSCK=y/' .config
        sed -i 's/^# CONFIG_MKE2FS is not set/CONFIG_MKE2FS=y/' .config
        ;;
    esac
  done

  sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config

  make oldconfig
}

build() {
  cd "${BUILD_DIR}/src"
  make -j"${ARTIX_MAKEFLAGS}" CFLAGS="-Os -s -pipe"
}

package() {
  cd "${BUILD_DIR}/src"
  make CONFIG_PREFIX="${PKG_DESTDIR}" install
}