#!/usr/bin/env bash
pkgname=zstd
pkgver=1.5.6
pkgrel=1
desc="Fast compression library"
url="https://github.com/facebook/zstd"

sources=(
  "https://github.com/facebook/zstd/releases/download/v${pkgver}/zstd-${pkgver}.tar.gz|SKIP|zstd-${pkgver}.tar.gz"
)

depends=()
makedepends=(base-devel)

prepare() {
  cd "${BUILD_DIR}"
  tar xf "${SOURCES_DIR}/zstd-${pkgver}.tar.gz"
  mv "zstd-${pkgver}" src
}

build() {
  cd "${BUILD_DIR}/src/lib"
  make -j"${ARTIX_MAKEFLAGS}" CFLAGS="${ARTIX_CFLAGS}"
}

package() {
  cd "${BUILD_DIR}/src/lib"
  make DESTDIR="${PKG_DESTDIR}" install
}