#!/usr/bin/env bash
set -Eeuo pipefail

_finalize_sync() {
    sync
}

_finalize_cleanup_installer_state() {
    if [[ -f /mnt/etc/artix-installer.conf ]]; then
        shred -u /mnt/etc/artix-installer.conf 2>/dev/null || rm -f /mnt/etc/artix-installer.conf
    fi
}

_finalize_unmount() {
    umount -R /mnt 2>/dev/null || true
    if [[ -e /dev/mapper/cryptroot ]]; then
        cryptsetup close cryptroot 2>/dev/null || true
    fi
}

_finalize_write_report() {
    local report="/mnt/root/artixforge-install-report.txt"
    mkdir -p /mnt/root
    {
        printf 'ArtixForge Installation Report\n'
        printf '===============================\n'
        printf 'Date: %s\n' "$(date)"
        printf 'Version: %s\n\n' "$(cat "${BASE_DIR}/VERSION" 2>/dev/null || echo unknown)"
        
        printf 'System Configuration:\n'
        printf '  Init: %s\n' "$(state_get INIT)"
        printf '  Bootloader: %s\n' "$(state_get BOOTLOADER)"
        printf '  Kernel: %s\n' "$(state_get KERNEL_CHOICE)"
        printf '  Filesystem: %s\n' "$(state_get FS_TYPE)"
        printf '  Desktop: %s\n' "$(state_get WM_DE)"
        printf '  Display Manager: %s\n' "$(state_get DISPLAY_MANAGER)"
        printf '  Display Stack: %s\n' "$(state_get X_STACK)"
        printf '  Network Stack: %s\n' "$(state_get NETWORK_STACK)"
        printf '  Audio Stack: %s\n\n' "$(state_get AUDIO_STACK)"

        printf 'Hardware:\n'
        printf '  GPU: %s\n' "$(get_gpu_info 2>/dev/null || echo unknown)"
        printf '  GPU Driver: %s\n' "$(state_get GPU_DRIVER unknown)"
        printf '  Virtualization: %s\n\n' "$(detect_vm 2>/dev/null || echo none)"

        printf 'User Accounts:\n'
        local count="${USER_COUNT:-1}"
        for ((i=1; i<=count; i++)); do
            local uname="${USER_${i}_NAME:-unnamed}"
            local ushell="${USER_${i}_SHELL:-/bin/bash}"
            local usudo="${USER_${i}_SUDO:-yes}"
            printf '  %s (shell: %s, sudo: %s)\n' "${uname}" "${ushell}" "${usudo}"
        done
        printf '\n'

        printf 'Disk Layout:\n'
        printf '  Target Disk: %s\n' "$(state_get DISK)"
        printf '  Partition Table: %s\n' "$([[ "${ARTIX_BOOT_MODE:-uefi}" == "bios" ]] && echo MBR || echo GPT)"
        printf '  LUKS: %s\n' "$(state_get USE_LUKS no)"
        printf '  LVM: %s\n' "$(state_get USE_LVM no)"
        printf '  Swap: %s\n\n' "$(state_get SWAP_ENABLED no)"

        printf 'Post-Install:\n'
        printf '  Run sudo pacman -Syu to update.\n'
        printf '  Issues? Check artix-debug.log or open an issue at:\n'
        printf '  https://github.com/realvolk/ArtixForge/issues\n'
    } > "${report}"
    chmod 644 "${report}"
    log_info "Installation report written to /root/artixforge-install-report.txt"
}

_finalize_success_dialog() {
    gum style --border rounded --padding 1 --bold --foreground "${GUM_TITLE_COLOR}" "Artix installation completed successfully!"
    gum style "You may now reboot."
    gum confirm "Press Enter to finish" --affirmative="OK" --timeout=0 2>/dev/null || true
}

stage_finalize() {
    if stage_should_skip finalize; then return 0; fi
    if ! stage_is_done post; then
        log_error "Post-install stage did not complete. Refusing to finalize."
        return 1
    fi

    log_info "Applying final system configuration..."
    _finalize_write_report
    _finalize_sync || { log_error "Failed to sync filesystem buffers."; return 1; }
    _finalize_cleanup_installer_state || { log_error "Failed to clean installer state."; return 1; }
    _finalize_unmount || { log_error "Failed to unmount installation target."; return 1; }

    stage_mark_done finalize
    _finalize_success_dialog
}