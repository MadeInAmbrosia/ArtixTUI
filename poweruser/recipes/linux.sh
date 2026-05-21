#!/usr/bin/env bash
pkgname=linux-custom
_major=7
pkgver=7.0.8
pkgrel=1
desc="Linux kernel built from source"
url="https://kernel.org"

sources=(
  "https://cdn.kernel.org/pub/linux/kernel/v${_major}.x/linux-${pkgver}.tar.xz|SKIP|linux-${pkgver}.tar.xz"
)

depends=()
makedepends=(base-devel bc cpio flex libelf pahole openssl)

feature_flags=(
  nvidia-support
  amd-support
)

prepare() {
  cd "${BUILD_DIR}"
  tar xf "${SOURCES_DIR}/linux-${pkgver}.tar.xz"
  mv "linux-${pkgver}" src
}

configure() {
  cd "${BUILD_DIR}/src"

  make allnoconfig

  scripts/config --enable 64BIT
  scripts/config --enable SMP
  scripts/config --enable PCI
  scripts/config --enable BLK_DEV_SD
  scripts/config --enable ATA
  scripts/config --enable SATA_AHCI
  scripts/config --enable NET
  scripts/config --enable INET
  scripts/config --enable PACKET
  scripts/config --enable TTY
  scripts/config --enable VT
  scripts/config --enable UNIX98_PTYS
  scripts/config --enable PROC_FS
  scripts/config --enable SYSFS
  scripts/config --enable DEVTMPFS
  scripts/config --enable TMPFS
  scripts/config --enable BINFMT_ELF
  scripts/config --enable PRINTK
  scripts/config --enable BLOCK
  scripts/config --enable MODULES
  scripts/config --enable MODULE_UNLOAD

  for feat in "${selected_features[@]}"; do
    case "${feat}" in
      nvidia-support)
        scripts/config --module DRM_NOUVEAU
        scripts/config --enable DRM_NOUVEAU_BACKLIGHT
        ;;
      amd-support)
        scripts/config --module DRM_AMDGPU
        scripts/config --enable DRM_AMDGPU_SI
        scripts/config --enable DRM_AMDGPU_CIK
        ;;
    esac
  done

  local depth
  depth="$(state_get KERNEL_CONFIG_DEPTH auto)"
  source "${POWERUSER_DIR}/lib/kconfig.bash"

  if [[ "${depth}" == "auto" || "${depth}" == "manual" ]]; then
    apply_basic_config
    apply_advanced_config
  elif [[ "${depth}" == "menuconfig" ]]; then
    make menuconfig
  fi

  make olddefconfig
}

build() {
  cd "${BUILD_DIR}/src"
  make -j"${ARTIX_MAKEFLAGS}"
  make modules -j"${ARTIX_MAKEFLAGS}"
}

package() {
  cd "${BUILD_DIR}/src"
  make INSTALL_MOD_PATH="${PKG_DESTDIR}" modules_install
  mkdir -p "${PKG_DESTDIR}/boot"
  cp arch/x86/boot/bzImage "${PKG_DESTDIR}/boot/vmlinuz-linux-custom"
  cp .config "${PKG_DESTDIR}/boot/config-${pkgver}"
}