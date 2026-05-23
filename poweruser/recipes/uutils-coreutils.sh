#!/usr/bin/env bash
pkgname=uutils-coreutils
pkgver=0.0.28
pkgrel=1
desc="Cross-platform Rust rewrite of GNU coreutils"
url="https://github.com/uutils/coreutils"

sources=(
  "https://github.com/uutils/coreutils/releases/download/${pkgver}/coreutils-${pkgver}.tar.gz|SKIP|coreutils-${pkgver}.tar.gz"
)

depends=()
makedepends=(base-devel rust cargo)

feature_flags=(
  multicall-binary
)

prepare() {
  cd "${BUILD_DIR}"
  tar xf "${SOURCES_DIR}/coreutils-${pkgver}.tar.gz"
  mv "coreutils-${pkgver}" src
}

configure() {
  cd "${BUILD_DIR}/src"
  :
}

build() {
  cd "${BUILD_DIR}/src"

  local features=""
  for feat in "${selected_features[@]}"; do
    case "${feat}" in
      multicall-binary)
        features+=" --features=feat_common_core"
        ;;
    esac
  done

  cargo build --release ${features} -j"${ARTIX_MAKEFLAGS}"
}

package() {
  cd "${BUILD_DIR}/src"
  mkdir -p "${PKG_DESTDIR}/usr/bin"

  local bin
  for bin in target/release/*; do
    [[ -f "${bin}" ]] && [[ -x "${bin}" ]] || continue
    local name
    name=$(basename "${bin}")
    [[ "${name}" =~ ^(build|deps|examples|incremental|\.) ]] && continue
    cp "${bin}" "${PKG_DESTDIR}/usr/bin/${name}"
  done
}