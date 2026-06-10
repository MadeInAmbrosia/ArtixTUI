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

    local first_boot_script="${iso_profile_dir}/airootfs/root/setup.sh"
    local needs_first_boot=0

    if [[ "${wm_de}" == "mango" || "${wm_de}" == "vxwm" ]]; then
        needs_first_boot=1
    fi
    if [[ "${kernel_choice}" == "linux-bazzite-bin" || "${kernel_choice}" == "tkg" ]]; then
        needs_first_boot=1
    fi

    if [[ ${needs_first_boot} -eq 1 ]]; then
        log_info "Creating first-boot setup script for non-repo packages..."
        cat > "${first_boot_script}" <<'SETUP'
#!/bin/bash
set -e

if grep -q 'ENABLE_ARCH_REPOS=yes' /etc/artix-installer.conf 2>/dev/null; then
    pacman -S --noconfirm --needed artix-archlinux-support archlinux-keyring
    if ! grep -q '^\[extra\]' /etc/pacman.conf; then
        cat >> /etc/pacman.conf <<'REPO'
[extra]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
REPO
    fi
    pacman -Sy --noconfirm
fi
SETUP

        if [[ "${wm_de}" == "mango" ]]; then
            cat >> "${first_boot_script}" <<'SETUP'

pacman -S --noconfirm --needed base-devel git
cd /tmp
git clone https://aur.archlinux.org/mangowm-git.git
chown -R nobody: /tmp/mangowm-git
su nobody -c 'cd /tmp/mangowm-git && makepkg -si --noconfirm'
rm -rf /tmp/mangowm-git
SETUP
        fi

        if [[ "${wm_de}" == "vxwm" ]]; then
            cat >> "${first_boot_script}" <<'SETUP'

pacman -S --noconfirm --needed base-devel git libx11 libxft libxinerama freetype2 xorg-server xorg-xinit
cd /tmp
git clone https://codeberg.org/wh1tepearl/vxwm.git
cd vxwm
make clean && make && make install
cd .. && rm -rf vxwm
SETUP
        fi

        if [[ "${kernel_choice}" == "linux-bazzite-bin" ]]; then
            cat >> "${first_boot_script}" <<'SETUP'

pacman -S --noconfirm --needed base-devel git
cd /tmp
git clone https://aur.archlinux.org/linux-bazzite-bin.git
chown -R nobody: /tmp/linux-bazzite-bin
su nobody -c 'cd /tmp/linux-bazzite-bin && makepkg -si --noconfirm --skippgpcheck'
rm -rf /tmp/linux-bazzite-bin
SETUP
        fi

        if [[ "${kernel_choice}" == "tkg" ]]; then
            cat >> "${first_boot_script}" <<'SETUP'

pacman -S --noconfirm --needed git
git clone https://github.com/Frogging-Family/linux-tkg /opt/linux-tkg || true
echo "TKG source ready in /opt/linux-tkg. Compile manually after reboot."
SETUP
        fi

        chmod +x "${first_boot_script}"

        # Auto-run on first boot via init-specific mechanism
        case "${init}" in
            openrc)
                mkdir -p "${iso_profile_dir}/live-overlay/etc/local.d"
                ln -sf /root/setup.sh "${iso_profile_dir}/live-overlay/etc/local.d/setup.start" 2>/dev/null || true
                ;;
            dinit)
                mkdir -p "${iso_profile_dir}/live-overlay/etc/dinit.d"
                cat > "${iso_profile_dir}/live-overlay/etc/dinit.d/iso-setup" <<'DINIT'
type = process
command = /root/setup.sh
restart = false
DINIT
                mkdir -p "${iso_profile_dir}/live-overlay/etc/dinit.d/boot.d"
                ln -sf ../iso-setup "${iso_profile_dir}/live-overlay/etc/dinit.d/boot.d/iso-setup" 2>/dev/null || true
                ;;
            runit)
                mkdir -p "${iso_profile_dir}/live-overlay/etc/runit/sv/iso-setup"
                cat > "${iso_profile_dir}/live-overlay/etc/runit/sv/iso-setup/run" <<'RUNIT'
#!/bin/sh
/root/setup.sh
RUNIT
                chmod +x "${iso_profile_dir}/live-overlay/etc/runit/sv/iso-setup/run"
                mkdir -p "${iso_profile_dir}/live-overlay/etc/runit/runsvdir/default"
                ln -sf /etc/runit/sv/iso-setup "${iso_profile_dir}/live-overlay/etc/runit/runsvdir/default/iso-setup" 2>/dev/null || true
                ;;
        esac

        log_info "First-boot setup script added for ${wm_de}${wm_de:+ / }${kernel_choice}"
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