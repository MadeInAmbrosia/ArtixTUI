#!/usr/bin/env bash
set -Eeuo pipefail

build_artix_iso() {
    local profile_name="${1:-Desktop}"
    local init="${2:-openrc}"
    local kernel="${3:-linux}"
    local offline="${4:-no}"
    local boot_mode="${5:-live}"

    local ISO_DIR
    ISO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

    local workspace="${HOME}/artools-workspace"
    local iso_profile_dir="${workspace}/iso-profiles/${profile_name}"
    local output_dir="${HOME}/artixforge-iso"

    if ! command -v buildiso >/dev/null; then
        log_info "Installing artools and iso-profiles..."
        pacman -S --noconfirm artools iso-profiles || die "Failed to install artools"
        modprobe loop
    fi

    mkdir -p "${workspace}"/{iso-profiles,chroot}

    log_info "Generating artools profile for ${profile_name} (${init}, ${boot_mode} mode)..."
    source "${ISO_DIR}/common.sh"
    generate_artools_profile "${iso_profile_dir}" "${profile_name}" "${init}" "${kernel}" "${boot_mode}"

    if [[ "${offline}" == "yes" ]]; then
        source "${ISO_DIR}/offline.sh"
        log_info "Building offline package repository..."
        build_offline_repo "${iso_profile_dir}/airootfs/mnt/repo" "${iso_profile_dir}/packages.x86_64"
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

    if [[ ${needs_chroot_build} -eq 1 ]]; then
        log_info "Non-repo packages detected. Building chroot first..."
        
        buildiso -p "${profile_name}" -i "${init}" -w "${workspace}" -x 2>&1 || die "buildiso -x failed"

        local chroot_dir="/var/lib/artools/buildiso/${profile_name}/artix/rootfs"
        if [[ ! -d "${chroot_dir}" ]]; then
            # Fallback: try workspace-based path
            chroot_dir="${workspace}/buildiso/${profile_name}/artix/rootfs"
        fi

        if [[ -d "${chroot_dir}" ]]; then
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
                " || log_warn "MangoWM build failed — ISO will still be created"
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
                " || log_warn "vxwm build failed — ISO will still be created"
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
                " || log_warn "Bazzite kernel build failed — ISO will still be created"
            fi
        else
            log_warn "Chroot directory not found — falling back to first-boot setup script"
        fi

        log_info "Squashing chroot and generating ISO..."
        buildiso -p "${profile_name}" -i "${init}" -w "${workspace}" -sc 2>&1 || die "buildiso -sc failed"
        buildiso -p "${profile_name}" -i "${init}" -w "${workspace}" -zc 2>&1 || die "buildiso -zc failed"
    else
        log_info "Building ISO (this may take a while)..."
        mkdir -p "${output_dir}"
        local iso_log="${workspace}/iso-build-$(date +%Y%m%d-%H%M%S).log"
        buildiso -p "${profile_name}" -i "${init}" -w "${workspace}" 2>&1 | tee "${iso_log}"
        local rc=${PIPESTATUS[0]}

        if [[ ${rc} -eq 0 ]]; then
            local iso_file
            iso_file=$(find "${output_dir}" -name '*.iso' -type f 2>/dev/null | head -n1)
            if [[ -z "${iso_file}" ]]; then
                # buildiso may output to workspace/iso/
                iso_file=$(find "${workspace}/iso" -name '*.iso' -type f 2>/dev/null | head -n1)
            fi
            log_info "ISO created: ${iso_file}"
            log_info "Build log: ${iso_log}"
            cp "${iso_log}" "${ISO_DIR}/" 2>/dev/null || true
            tui_msg_quick "ISO Ready" "ISO created at:\n${iso_file}\n\nBuild log:\n${iso_log}\n${ISO_DIR}/"
        else
            log_error "ISO build failed. Check log: ${iso_log}"
            cp "${iso_log}" "${ISO_DIR}/" 2>/dev/null || true
            die "buildiso exited with an error"
        fi
        return 0
    fi

    log_info "Build complete. Locating ISO..."
    local iso_file
    iso_file=$(find "${output_dir}" -name '*.iso' -type f 2>/dev/null | head -n1)
    if [[ -z "${iso_file}" ]]; then
        iso_file=$(find "${workspace}/iso" -name '*.iso' -type f 2>/dev/null | head -n1)
    fi

    if [[ -n "${iso_file}" ]]; then
        log_info "ISO created: ${iso_file}"
        tui_msg_quick "ISO Ready" "ISO created at:\n${iso_file}"
    else
        log_warn "ISO file not found in ${output_dir} or ${workspace}/iso"
        log_warn "Check ${workspace} for the output"
    fi
}