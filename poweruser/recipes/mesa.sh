#!/usr/bin/env bash
pkgname=mesa
pkgver=25.0.2
_major=25
pkgrel=1
desc="Open-source OpenGL/Vulkan graphics drivers"
url="https://mesa3d.org"

sources=(
  "https://archive.mesa3d.org/mesa-${pkgver}.tar.xz|SKIP|mesa-${pkgver}.tar.xz"
)

depends=(libdrm libx11 libxext libxrandr libxdamage wayland-protocols)
makedepends=(base-devel meson ninja python-mako glslang)

feature_flags=(
  gallium-radeonsi
  gallium-intel
  gallium-nouveau
  gallium-virtio
  vulkan-amd
  vulkan-intel
  video-codecs
)

prepare() {
  cd "${BUILD_DIR}"
  tar xf "${SOURCES_DIR}/mesa-${pkgver}.tar.xz"
  mv "mesa-${pkgver}" src
  mkdir build
}

configure() {
  cd "${BUILD_DIR}/build"

  local meson_opts=(-Dprefix=/usr -Dbuildtype=release)

  for feat in "${selected_features[@]}"; do
    case "${feat}" in
      gallium-radeonsi) meson_opts+=(-Dgallium-drivers=radeonsi) ;;
      gallium-intel)    meson_opts+=(-Dgallium-drivers=i915,iris) ;;
      gallium-nouveau)  meson_opts+=(-Dgallium-drivers=nouveau) ;;
      gallium-virtio)   meson_opts+=(-Dgallium-drivers=virgl) ;;
      vulkan-amd)       meson_opts+=(-Dvulkan-drivers=amd) ;;
      vulkan-intel)     meson_opts+=(-Dvulkan-drivers=intel) ;;
      video-codecs)     meson_opts+=(-Dvideo-codecs=enabled) ;;
    esac
  done

  meson setup ../src "${meson_opts[@]}" \
    -Dc_args="${ARTIX_CFLAGS}" \
    -Dcpp_args="${ARTIX_CXXFLAGS}"
}

build() {
  ninja -C "${BUILD_DIR}/build" -j"${ARTIX_MAKEFLAGS}"
}

package() {
  DESTDIR="${PKG_DESTDIR}" ninja -C "${BUILD_DIR}/build" install
}