#!/usr/bin/env bash
pkgname=busybox
pkgver=1.36.1
pkgrel=1
desc="BusyBox multi-call binary (coreutils replacement)"
url="https://busybox.net"

sources=(
  "https://busybox.net/downloads/busybox-${pkgver}.tar.bz2|SKIP|busybox-${pkgver}.tar.bz2"
)

depends=()
makedepends=(base-devel)

feature_flags=(
  static-build
)

prepare() {
  cd "${BUILD_DIR}"
  tar xf "${SOURCES_DIR}/busybox-${pkgver}.tar.bz2"
  mv "busybox-${pkgver}" src
}

configure() {
  cd "${BUILD_DIR}/src"
  make defconfig

  for feat in "${selected_features[@]}"; do
    case "${feat}" in
      static-build)
        sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
        ;;
    esac
  done

  make oldconfig
}

build() {
  cd "${BUILD_DIR}/src"
  make -j"${ARTIX_MAKEFLAGS}"
}

package() {
  cd "${BUILD_DIR}/src"
  make CONFIG_PREFIX="${PKG_DESTDIR}" install
}