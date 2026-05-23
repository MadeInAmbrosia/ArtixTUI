#!/usr/bin/env bash
pkgname=busybox-init
pkgver=1.36.1
pkgrel=1
desc="BusyBox with init support (minimal init system)"
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

  sed -i 's/^# CONFIG_INIT is not set/CONFIG_INIT=y/' .config
  sed -i 's/^# CONFIG_FEATURE_USE_INITTAB is not set/CONFIG_FEATURE_USE_INITTAB=y/' .config
  sed -i 's/^# CONFIG_HALT is not set/CONFIG_HALT=y/' .config
  sed -i 's/^# CONFIG_REBOOT is not set/CONFIG_REBOOT=y/' .config
  sed -i 's/^# CONFIG_POWEROFF is not set/CONFIG_POWEROFF=y/' .config
  sed -i 's/^# CONFIG_GETTY is not set/CONFIG_GETTY=y/' .config
  sed -i 's/^# CONFIG_FEATURE_SH_IS_BASH is not set/CONFIG_FEATURE_SH_IS_BASH=y/' .config

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