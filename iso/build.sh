#!/usr/bin/env bash
set -Eeuo pipefail

ISO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${BASE_DIR:-$(cd -- "${ISO_DIR}/.." && pwd)}"

build_artix_iso() {
    local profile_name="${1:-Desktop}"
    local init="${2:-openrc}"
    local kernel="${3:-linux}"
    local offline="${4:-no}"
    local boot_mode="${5:-live}"
    local user_output_dir="${6:-${HOME}/ArtixForge-ISO}"

    local workspace="${HOME}/artools-workspace"
    local iso_output_dir="${workspace}/iso"
    local iso_profile_dir="${workspace}/iso-profiles/${profile_name}"

    if ! command -v buildiso >/dev/null; then
        log_info "Installing artools and iso-profiles..."
        pacman -S --noconfirm artools iso-profiles || die "Failed to install artools"
        modprobe loop
    fi

    mkdir -p "${workspace}"/{iso-profiles,chroot,iso}

    log_info "Generating artools profile for ${profile_name} (${init}, ${boot_mode} mode)..."
    source "${ISO_DIR}/common.sh"
    generate_artools_profile "${iso_profile_dir}" "${profile_name}" "${init}" "${kernel}" "${boot_mode}"

    if [[ "${offline}" == "yes" ]]; then
        source "${ISO_DIR}/offline.sh"
        log_info "Building offline package repository..."
        
        local offline_pkg_list="${iso_profile_dir}/packages.x86_64"
        if [[ -f /tmp/artix-installer/iso-target-state.conf ]]; then
            log_info "Generating target system package list from target state..."
            source /tmp/artix-installer/iso-target-state.conf
            generate_iso_package_list "${INIT:-openrc}" "${KERNEL_CHOICE:-linux}" > "${iso_profile_dir}/packages-target.x86_64"
            offline_pkg_list="${iso_profile_dir}/packages-target.x86_64"
        fi
        
        build_offline_repo "${iso_profile_dir}/airootfs/mnt/repo" "${offline_pkg_list}"
        mkdir -p "${iso_profile_dir}/airootfs/etc"
        cat > "${iso_profile_dir}/airootfs/etc/pacman.conf" <<'PACMAN'
[options]
Architecture = auto

[custom]
SigLevel = Optional
Server = file:///mnt/repo/

[system]
Include = /etc/pacman.d/mirrorlist-artix

[world]
Include = /etc/pacman.d/mirrorlist-artix

[galaxy]
Include = /etc/pacman.d/mirrorlist-artix
PACMAN
    fi

    local wm_de kernel_choice
    wm_de="$(state_get WM_DE none)"
    kernel_choice="$(state_get KERNEL_CHOICE linux)"

    local needs_chroot_build=0
    if [[ "${wm_de}" == "mango" || "${wm_de}" == "vxwm" ]]; then
        needs_chroot_build=1
    fi
    if [[ "${kernel_choice}" == "linux-bazzite-bin" ]]; then
        needs_chroot_build=1
    fi

    log_info "Refreshing build keys..."
    pacman -S --noconfirm --needed artix-keyring
    pacman-key --populate artix
    pacman-key --recv-keys 78C9C713EAD7BEC69087447332E21894258C6105 --keyserver hkp://keyserver.ubuntu.com 2>/dev/null || true
    pacman-key --lsign-key 78C9C713EAD7BEC69087447332E21894258C6105 2>/dev/null || log_warn "Buildbot key trust failed – build may still work"

    if [[ ${needs_chroot_build} -eq 1 ]]; then
        log_info "Non-repo packages detected. Building chroot first..."
        
        buildiso -p "${profile_name}" -i "${init}" -w "${workspace}" -x 2>&1 || die "buildiso -x failed"

        local chroot_dir=""
        local search_paths=(
            "/var/lib/artools/buildiso/${profile_name}/artix/rootfs"
            "${workspace}/buildiso/${profile_name}/artix/rootfs"
        )
        for candidate in "${search_paths[@]}"; do
            if [[ -d "${candidate}" && -x "${candidate}/bin/sh" ]]; then
                chroot_dir="${candidate}"
                break
            fi
        done
        if [[ -z "${chroot_dir}" ]]; then
            chroot_dir=$(find "${workspace}" -type d -name rootfs -path "*/artix/rootfs" 2>/dev/null | head -n1)
        fi

        if [[ -n "${chroot_dir}" && -d "${chroot_dir}" ]]; then
            log_info "Entering chroot at ${chroot_dir} to build non-repo packages..."

            if [[ "${wm_de}" == "mango" ]]; then
                log_info "Building MangoWM from AUR..."
                artix-chroot "${chroot_dir}" bash -c "
                    pacman -S --noconfirm --needed base-devel git
                    cd /tmp
                    git clone https://aur.archlinux.org/mangowm-git.git
                    chown -R nobody: /tmp/mangowm-git
                    su nobody -c 'cd /tmp/mangowm-git && makepkg -si --noconfirm'
                    rm -rf /tmp/mangowm-git
                " || die "MangoWM build failed"
            fi

            if [[ "${wm_de}" == "vxwm" ]]; then
                log_info "Building vxwm from source..."
                artix-chroot "${chroot_dir}" bash -c "
                    pacman -S --noconfirm --needed base-devel git libx11 libxft libxinerama freetype2 xorg-server xorg-xinit
                    cd /tmp
                    git clone https://codeberg.org/wh1tepearl/vxwm.git
                    cd vxwm
                    make clean && make && make install
                    cd .. && rm -rf vxwm
                " || die "vxwm build failed"
            fi

            if [[ "${kernel_choice}" == "linux-bazzite-bin" ]]; then
                log_info "Building bazzite kernel from AUR..."
                artix-chroot "${chroot_dir}" bash -c "
                    pacman -S --noconfirm --needed base-devel git
                    cd /tmp
                    git clone https://aur.archlinux.org/linux-bazzite-bin.git
                    chown -R nobody: /tmp/linux-bazzite-bin
                    su nobody -c 'cd /tmp/linux-bazzite-bin && makepkg -si --noconfirm --skippgpcheck'
                    rm -rf /tmp/linux-bazzite-bin
                " || die "Bazzite kernel build failed"
            fi
        else
            die "Chroot directory not found – cannot customize ISO. Artools may have changed paths."
        fi

        log_info "Squashing chroot and generating ISO..."
        buildiso -p "${profile_name}" -i "${init}" -w "${workspace}" -sc 2>&1 || die "buildiso -sc failed"
        buildiso -p "${profile_name}" -i "${init}" -w "${workspace}" -zc 2>&1 || die "buildiso -zc failed"
    else
        log_info "Building ISO (this may take a while)..."
        local iso_log="${workspace}/iso-build-$(date +%Y%m%d-%H%M%S).log"
        buildiso -p "${profile_name}" -i "${init}" -w "${workspace}" 2>&1 | tee "${iso_log}"
        local rc=${PIPESTATUS[0]}

        if [[ ${rc} -eq 0 ]]; then
            local iso_file
            iso_file=$(find "${iso_output_dir}" -name '*.iso' -type f 2>/dev/null | head -n1)
            if [[ -n "${iso_file}" ]]; then
                mkdir -p "${user_output_dir}"
                cp "${iso_file}" "${user_output_dir}/"
                log_info "ISO created: ${user_output_dir}/${iso_file##*/}"
                log_info "Build log: ${iso_log}"
                cp "${iso_log}" "${user_output_dir}/" 2>/dev/null || true
                tui_msg_quick "ISO Ready" "ISO created at:\n${user_output_dir}/${iso_file##*/}\n\nBuild log:\n${user_output_dir}/iso-build-*.log"
            else
                log_error "ISO file not found in ${iso_output_dir}"
                die "buildiso completed but no ISO was produced"
            fi
        else
            log_error "ISO build failed. Check log: ${iso_log}"
            cp "${iso_log}" "${ISO_DIR}/" 2>/dev/null || true
            die "buildiso exited with an error"
        fi
        return 0
    fi

    log_info "Build complete. Locating ISO..."
    local iso_file
    iso_file=$(find "${iso_output_dir}" -name '*.iso' -type f 2>/dev/null | head -n1)

    if [[ -n "${iso_file}" ]]; then
        mkdir -p "${user_output_dir}"
        cp "${iso_file}" "${user_output_dir}/"
        log_info "ISO created: ${user_output_dir}/${iso_file##*/}"
        tui_msg_quick "ISO Ready" "ISO created at:\n${user_output_dir}/${iso_file##*/}"
    else
        log_warn "ISO file not found in ${iso_output_dir}"
        log_warn "Check ${workspace} for the output"
    fi
}