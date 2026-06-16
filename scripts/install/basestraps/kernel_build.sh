#!/usr/bin/env bash
set -Eeuo pipefail

basestrap_build_tkg() {
    log_info "Building TKG kernel (using TKG patches, AF's poweruser process)..."

    local tkg_dir="/tmp/linux-tkg"
    local kernel_src="/tmp/linux-custom"
    rm -rf "${tkg_dir}" "${kernel_src}"

    git clone --depth 1 https://github.com/Frogging-Family/linux-tkg.git "${tkg_dir}"

    local artix_kver=$(pacman -Si linux 2>/dev/null | grep Version | awk '{print $3}' | cut -d- -f1)
    [[ -z "${artix_kver}" ]] && artix_kver=$(uname -r | cut -d- -f1)

    git clone --depth 1 --branch "v${artix_kver}" \
        https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git "${kernel_src}" 2>/dev/null || \
    git clone --depth 1 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git "${kernel_src}"

    cd "${kernel_src}"

    local kver=$(make kernelrelease 2>/dev/null || make kernelversion | cut -d. -f1-2)
    local patch_dir="${tkg_dir}/linux-tkg-patches/${kver}"
    if [[ -d "${patch_dir}" ]]; then
        log_info "Applying TKG patches for kernel ${kver}..."
        for patch in "${patch_dir}"/*.patch; do
            patch -Np1 < "$patch" || log_warn "Patch ${patch} failed – continuing"
        done
    fi

    make defconfig
    make -j$(nproc)
    make modules_install INSTALL_MOD_PATH=/mnt
    make install INSTALL_PATH=/mnt/boot

    local kver_full=$(ls -1 /mnt/lib/modules/ | grep -E '^[0-9]' | sort -V | tail -1)
    if [[ -n "${kver_full}" ]]; then
        artix-chroot /mnt mkinitcpio -P
        if [[ -d /mnt/boot/grub ]]; then
            artix-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
        fi
        log_info "TKG kernel (${kver_full}) installed"
    else
        die "TKG build failed – no kernel modules found in /mnt/lib/modules"
    fi

    rm -rf "${tkg_dir}" "${kernel_src}"
    log_info "TKG build complete."
}

basestrap_build_bazzite() {
    log_info "Building linux-bazzite-bin from AUR..."

    local build_dir='/tmp/linux-bazzite-bin'
    rm -rf "${build_dir}"
    git clone 'https://aur.archlinux.org/linux-bazzite-bin.git' "${build_dir}" || {
        log_error "Failed to clone linux-bazzite-bin AUR repo."
        return 1
    }
    useradd -m builduser 2>/dev/null || true
    chown -R builduser:builduser "${build_dir}"
    su builduser -c "cd '${build_dir}' && makepkg -s --noconfirm --needed --skippgpcheck" &>/tmp/bazzite-build.log || {
        log_error "Failed to build linux-bazzite-bin."
        log_error "Last 20 lines of build log:"
        tail -20 /tmp/bazzite-build.log 2>/dev/null | while IFS= read -r line; do log_error "  ${line}"; done
        return 1
    }
    pacman -U --noconfirm "${build_dir}"/*.pkg.tar.* || {
        log_error "Failed to install linux-bazzite-bin package."
        return 1
    }
    local kver
    kver=$(ls -1 /usr/lib/modules/ | grep bazzite | sort -V | tail -1)
    if [[ -n "${kver}" && -f "/usr/lib/modules/${kver}/vmlinuz" ]]; then
        cp "/usr/lib/modules/${kver}/vmlinuz" "/mnt/boot/vmlinuz-linux-bazzite"
        cp -a "/usr/lib/modules/${kver}" /mnt/lib/modules/ 2>/dev/null || true
    fi
    rm -rf "${build_dir}"
    log_info "Bazzite kernel installed."
}