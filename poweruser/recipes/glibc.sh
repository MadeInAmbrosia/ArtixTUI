#!/usr/bin/env bash
# USE THIS IF YOU'RE WILLING TO NUKE YOUR OWN SYSTEM. GOOD LUCK.

pkgname=glibc
pkgver=2.40
pkgrel=1
desc="GNU C Library (use with caution)"
url="https://gnu.org/software/libc"

sources=(
  "https://ftp.gnu.org/gnu/glibc/glibc-${pkgver}.tar.gz|SKIP|glibc-${pkgver}.tar.gz"
)

depends=()
makedepends=(base-devel gettext bison gawk)

# WHY Y NO FEATURE FLAGS?
# Reason: You'll break your system for nothing
# (Cope)

prepare() {
  cd "${BUILD_DIR}"
  tar xf "${SOURCES_DIR}/glibc-${pkgver}.tar.gz"
  mv "glibc-${pkgver}" src
  mkdir build
}

configure() {
  cd "${BUILD_DIR}/build"
  ../src/configure --prefix=/usr --disable-werror --enable-stack-protector=strong
}

build() {
  make -C "${BUILD_DIR}/build" -j"${ARTIX_MAKEFLAGS}"
}

package() {
  make -C "${BUILD_DIR}/build" DESTDIR="${PKG_DESTDIR}" install
}