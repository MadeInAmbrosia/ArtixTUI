#!/usr/bin/env bash
set -Eeuo pipefail

ATA_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${BASE_DIR:-$(cd -- "${ATA_DIR}/../.." && pwd)}"

source "${BASE_DIR}/scripts/common.sh" 2>/dev/null || true
source "${BASE_DIR}/scripts/state.sh" 2>/dev/null || true
source "${BASE_DIR}/scripts/recovery/detect.sh" 2>/dev/null || true
source "${BASE_DIR}/scripts/recovery/core.sh" 2>/dev/null || true

source "${BASE_DIR}/migrations/inits/common.sh" 2>/dev/null || true
source "${BASE_DIR}/migrations/des/common.sh" 2>/dev/null || true

source "${ATA_DIR}/ata-detect.sh"
source "${ATA_DIR}/ata-backup.sh"
source "${ATA_DIR}/ata-map.sh"
source "${ATA_DIR}/ata-convert.sh"
source "${ATA_DIR}/ata-restore.sh"

ata_migrate_main() {
    if [[ -d /run/artix/sfs/rootfs ]]; then
        tui_msg "Cannot Run from Live ISO" \
            "Arch → Artix migration must be run from the booted Arch system.\n\nBoot into your Arch installation and run ArtixForge from there."
        return 0
    fi

    if ! grep -q '^ID=arch' /etc/os-release 2>/dev/null; then
        tui_msg "Not Arch Linux" "This system doesn't appear to be Arch Linux."
        return 0
    fi

    tui_msg "Arch → Artix Migration" \
"This will convert your Arch Linux system to Artix.

WHAT CAN BE MIGRATED AUTOMATICALLY:
  ✓ Packages (with version mismatch warnings)
  ✓ Desktop environment and display manager
  ✓ User files and home directories
  ✓ System configs (/etc/fstab, /etc/hostname, locale)
  ✓ Enabled system services → init equivalents
  ✓ WiFi passwords and network configs
  ✓ SSH keys and host configs
  ✓ Firewall rules and cron jobs
  ✓ Pacman hooks (systemd-dependent ones disabled)
  ✓ PAM modules (pam_systemd → pam_elogind)
  ✓ mkinitcpio hooks (systemd → udev/encrypt)
  ✓ systemd timers → cron (OnCalendar + basic monotonic)
  ✓ crypttab → kernel parameters
  ✓ DNS resolver fix
  ✓ systemd-boot → GRUB (auto-install)
  ✓ Flatpaks (remotes + apps preserved)
  ✓ DKMS modules (auto-rebuild)
  ✓ systemd-homed users (with password unlock)
  ✓ systemd --user services → autostart
  ✓ AUR packages (attempt batch reinstall)

WHAT WILL BE BACKED UP:
  • All of /home
  • /etc, /boot, /usr/local
  • Pacman database
  • System journal (text export)
  • Everything to /arch-migration-backup-YYYYMMDD-HHMMSS"

    if ! tui_yesno "Begin Migration" "This is destructive. Proceed?"; then
        return 0
    fi

    ata_detect_all

    local target_init
    target_init=$(tui_menu "Choose Init System" "Select your new init:" \
        "openrc" "runit" "dinit" "s6") || return 0
    state_set INIT "${target_init}"

    local use_arch_repos="yes"
    tui_yesno "Arch Repositories" "Keep access to Arch repositories for AUR helpers?" || use_arch_repos="no"
    state_set ENABLE_ARCH_REPOS "${use_arch_repos}"

    local aur_helper=""
    if [[ -s /tmp/ata-aur.txt ]]; then
        local aur_count
        aur_count=$(wc -l < /tmp/ata-aur.txt)
        if tui_yesno "AUR Packages" "${aur_count} AUR packages detected.\n\nAttempt to reinstall them automatically after migration?"; then
            aur_helper=$(tui_menu "AUR Helper" "Select AUR helper:" "paru" "yay" "Skip") || aur_helper=""
            [[ "${aur_helper}" == "Skip" ]] && aur_helper=""
        fi
    fi

    local has_homed=0
    if [[ -s /tmp/ata-homed.txt ]]; then
        has_homed=1
        tui_msg "systemd-homed Detected" "Users with systemd-homed were found.\n\nTheir home directories will be unlocked and migrated to standard /home if you provide their passwords."
    fi

    local de aur_count flatpak_count snap_count
    de=$(state_get WM_DE none)
    aur_count=$(wc -l < /tmp/ata-aur.txt 2>/dev/null || echo 0)
    flatpak_count=$(wc -l < /tmp/ata-flatpak.txt 2>/dev/null || echo 0)
    snap_count=$(wc -l < /tmp/ata-snap.txt 2>/dev/null || echo 0)

    local summary=""
    summary+="Desktop: ${de}"$'\n'
    summary+="AUR packages: ${aur_count}"$'\n'
    summary+="Flatpaks: ${flatpak_count}"$'\n'
    summary+="Snaps: ${snap_count}"$'\n'
    summary+="Target init: ${target_init}"$'\n'
    summary+="Arch repos: ${use_arch_repos}"$'\n'
    [[ -n "${aur_helper}" ]] && summary+="AUR helper: ${aur_helper}"$'\n'
    tui_msg "Migration Summary" "${summary}"

    if ! tui_yesno "Final Confirmation" "This is the point of no return.\n\nAll changes are backed up.\n\nProceed with migration?"; then
        log_info "Migration cancelled."
        return 0
    fi

    local backup_dir="/arch-migration-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "${backup_dir}"
    chmod 700 "${backup_dir}"
    state_set MIGRATION_BACKUP_DIR "${backup_dir}"
    ata_backup_all "${backup_dir}"

    ata_convert_all

    [[ ${has_homed} -eq 1 ]] && ata_migrate_homed_users "${backup_dir}"

    ata_build_package_map
    ata_show_migration_list

    log_info "Pre-downloading Artix base packages..."
    cache_artix_packages "${target_init}"

    prepare_artix_repos
    clean_pacman_cache
    install_artix_keyring

    remove_systemd

    install_target_init "systemd" "${target_init}"
    _pacman -S --noconfirm base base-devel grub linux linux-headers mkinitcpio rsync artix-branding-base

    reinstall_artix_packages

    [[ "${de}" != "none" ]] && run_de_migration "none" "${de}"

    log_info "Enabling selected services..."
    while IFS= read -r unit; do
        local mapped
        mapped=$(awk -F'|' -v u="${unit}" '$1==u {print $4}' "${ATA_MAP_CACHE}")
        [[ -n "${mapped}" && "${mapped}" != "MISSING" ]] && _enable_service "${mapped}" "${target_init}"
    done < /tmp/ata-migrate-selection.txt 2>/dev/null

    ata_convert_user_services
    ata_convert_systemd_boot
    ata_rebuild_dkms
    ata_restore_user_data "${backup_dir}"
    ata_restore_flatpaks "${backup_dir}"
    ata_restore_network_credentials "${backup_dir}"

    if [[ -n "${aur_helper}" && -s /tmp/ata-aur.txt ]]; then
        ata_reinstall_aur "${aur_helper}"
    fi

    if [[ -s /tmp/ata-exotic-mounts.txt ]]; then
        log_warn "Exotic mounts (NFS/CIFS/etc.) found in /etc/fstab. Verify after boot."
    fi

    log_info "Rebuilding initramfs..."
    _chroot mkinitcpio -P 2>/dev/null || log_warn "mkinitcpio failed"
    update_bootloader

    rm -f /tmp/ata-*.txt /tmp/ata-pkg-map.txt

    tui_msg "Migration Complete" \
"Your system has been converted to Artix Linux (${target_init}).

Backup: ${backup_dir}
Journal: ${backup_dir}/journal-full.txt

AFTER REBOOT:
  • Check services with your init's service manager
  • Verify DNS in /etc/resolv.conf
  • AUR packages: check ${backup_dir}/lists/ata-aur.txt"

    if tui_yesno "Reboot" "Reboot now?"; then
        reboot
    fi
}