#!/usr/bin/env bash
pkgname=openssl
pkgver=3.4.1
pkgrel=1
desc="SSL/TLS cryptography library"
url="https://openssl.org"

sources=(
  "https://openssl.org/source/openssl-${pkgver}.tar.gz|SKIP|openssl-${pkgver}.tar.gz"
)

depends=()
makedepends=(base-devel perl)

feature_flags=(
  enable-asm
  enable-ktls
)

prepare() {
  cd "${BUILD_DIR}"
  tar xf "${SOURCES_DIR}/openssl-${pkgver}.tar.gz"
  mv "openssl-${pkgver}" src
}

configure() {
  cd "${BUILD_DIR}/src"

  local opts=(--prefix=/usr --openssldir=/etc/ssl shared)
  opts+=(-Wl,-rpath,/usr/lib)

  for feat in "${selected_features[@]}"; do
    case "${feat}" in
      enable-asm) opts+=("enable-asm") ;;
      enable-ktls) opts+=("enable-ktls") ;;
    esac
  done

  ./Configure CFLAGS="${ARTIX_CFLAGS}" "${opts[@]}"
}

build() {
  cd "${BUILD_DIR}/src"
  make -j"${ARTIX_MAKEFLAGS}"
}

package() {
  cd "${BUILD_DIR}/src"
  make DESTDIR="${PKG_DESTDIR}" install_sw
}