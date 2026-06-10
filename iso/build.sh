#!/usr/bin/env bash
set -Eeuo pipefail

build_artix_iso() {
    local profile_name="${1:-Desktop}"
    local init="${2:-openrc}"
    local kernel="${3:-linux}"
    local offline="${4:-no}"
    local boot_mode="${5:-live}"

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
        build_offline_repo "${iso_profile_dir}/airootfs/mnt/repo"
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

    log_info "Building ISO (this may take a while)..."
    mkdir -p "${output_dir}"
    local iso_log="${workspace}/iso-build-$(date +%Y%m%d-%H%M%S).log"
    if buildiso -p "${profile_name}" -i "${init}" -t "${output_dir}" -w "${workspace}" 2>&1 | tee "${iso_log}"; then
        local iso_file
        iso_file=$(find "${output_dir}" -name '*.iso' -type f | head -n1)
        log_info "ISO created: ${iso_file}"
        log_info "Build log: ${iso_log}"
        cp "${iso_log}" "${ISO_DIR}/" 2>/dev/null || true
        tui_msg_quick "ISO Ready" "ISO created at:\n${iso_file}\n\nBuild log:\n${iso_log}\n${ISO_DIR}/"
    else
        log_error "ISO build failed. Check log: ${iso_log}"
        cp "${iso_log}" "${ISO_DIR}/" 2>/dev/null || true
        die "buildiso exited with an error"
    fi
}