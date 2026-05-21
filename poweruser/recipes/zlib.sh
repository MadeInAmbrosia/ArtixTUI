#!/usr/bin/env bash
pkgname=zlib
pkgver=1.3.1
pkgrel=1
desc="Compression library"
url="https://zlib.net"

sources=(
  "https://zlib.net/zlib-${pkgver}.tar.gz|SKIP|zlib-${pkgver}.tar.gz"
)

depends=()
makedepends=(base-devel)

prepare() {
  cd "${BUILD_DIR}"
  tar xf "${SOURCES_DIR}/zlib-${pkgver}.tar.gz"
  mv "zlib-${pkgver}" src
}

configure() {
  cd "${BUILD_DIR}/src"
  ./configure --prefix=/usr --shared --libdir=/usr/lib
}

build() {
  cd "${BUILD_DIR}/src"
  make -j"${ARTIX_MAKEFLAGS}" CFLAGS="${ARTIX_CFLAGS}"
}

package() {
  cd "${BUILD_DIR}/src"
  make DESTDIR="${PKG_DESTDIR}" install
}