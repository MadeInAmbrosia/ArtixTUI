#!/usr/bin/env bash
set -Eeuo pipefail

repair_fstab() {
    local issues
    issues=$(state_get FSTAB_ISSUES none)
    if [[ "${issues}" == "missing" ]]; then
        log_warn "fstab is missing. Regenerating..."
        if tui_yesno "Repair fstab" "Regenerate fstab from current mounts?"; then
            fstabgen -U /mnt > /mnt/etc/fstab
            log_info "fstab regenerated."
        fi
    elif [[ "${issues}" != "none" ]]; then
        log_warn "fstab has stale UUIDs: ${issues}"
        if tui_yesno "Repair fstab" "Regenerate fstab to fix UUIDs?"; then
            fstabgen -U /mnt > /mnt/etc/fstab
            log_info "fstab regenerated."
        fi
    fi
}

repair_pacman() {
    local issues
    issues=$(state_get PACMAN_ISSUES none)
    if [[ "${issues}" =~ stale-lock ]]; then
        log_warn "Pacman lock found."
        if tui_yesno "Remove lock" "Remove stale pacman lock?"; then
            rm -f /mnt/var/lib/pacman/db.lck
            log_info "Lock removed."
        fi
    fi
    if [[ "${issues}" =~ base-missing ]]; then
        log_warn "Base system packages missing or corrupted."
        if tui_yesno "Reinstall base" "Reinstall base packages?"; then
            basestrap /mnt base base-devel
            log_info "Base packages reinstalled."
        fi
    fi
    if [[ "${issues}" =~ broken-pkgs ]]; then
        log_warn "Some packages have missing files. Run 'pacman -Qk' to list them."
    fi
}

repair_boot() {
    local issues
    issues=$(state_get BOOT_ISSUES none)
    if [[ "${issues}" =~ no-kernel ]]; then
        log_warn "Kernel image missing from /boot."
        if tui_yesno "Reinstall kernel" "Reinstall kernel package?"; then
            local kernel_choice kernel_pkg
            kernel_choice=$(state_get KERNEL_CHOICE linux)
            case "${kernel_choice}" in
                linux)          kernel_pkg="linux" ;;
                linux-zen)      kernel_pkg="linux-zen" ;;
                linux-lts)      kernel_pkg="linux-lts" ;;
                linux-hardened) kernel_pkg="linux-hardened" ;;
                *)              kernel_pkg="linux" ;;
            esac
            artix-chroot /mnt pacman -S --noconfirm "${kernel_pkg}" "${kernel_pkg}-headers"
        fi
    fi
    if [[ "${issues}" =~ no-initramfs ]]; then
        log_warn "Initramfs missing."
        if tui_yesno "Regenerate initramfs" "Run mkinitcpio?"; then
            artix-chroot /mnt mkinitcpio -P
        fi
    fi
    if [[ "${issues}" =~ no-efi-entry ]]; then
        log_warn "No EFI boot entry for Artix."
        if tui_yesno "Reinstall bootloader" "Reinstall GRUB?"; then
            artix-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ARTIX
            artix-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
        fi
    fi
}

repair_kernel() {
    log_info "Checking custom kernel health..."
    if [[ ! -f /mnt/boot/vmlinuz-linux-custom ]]; then
        log_warn "Custom kernel not found – nothing to repair."
        return 0
    fi

    if ! tui_yesno "Repair Custom Kernel" "Rebuild the custom kernel with the latest recipe?"; then
        return 0
    fi

    POWERUSER_DIR="${BASE_DIR}/poweruser"

    if [[ ! -f "${POWERUSER_DIR}/recipes/linux.sh" ]]; then
        log_info "Fetching kernel recipe from community repository..."
        local list_url="https://raw.githubusercontent.com/realvolk/ArtixForge-recipes/main/.LIST"
        local repo_base="https://raw.githubusercontent.com/realvolk/ArtixForge-recipes/main"
        curl -fsSL "${list_url}" -o /tmp/artix-recipes.list 2>/dev/null
        local section
        section=$(awk -F'|' -v pkg="linux" '$1 == pkg {print $2}' /tmp/artix-recipes.list 2>/dev/null)
        if [[ -n "${section}" ]]; then
            curl -sL "${repo_base}/${section}/linux.sh" -o "${POWERUSER_DIR}/recipes/linux.sh"
        fi
        rm -f /tmp/artix-recipes.list
    fi

    source "${POWERUSER_DIR}/lib/common.sh"
    source "${POWERUSER_DIR}/lib/flags.bash"
    source "${POWERUSER_DIR}/lib/recipe.bash"
    source "${POWERUSER_DIR}/lib/builder.bash"
    source "${POWERUSER_DIR}/lib/validate.bash"

    local profile_name
    if [[ -f /mnt/usr/share/artix-poweruser/profile/active ]]; then
        profile_name=$(tr -d '[:space:]' < /mnt/usr/share/artix-poweruser/profile/active)
    else
        profile_name="default"
    fi

    export POWERUSER_PROFILE="${profile_name}"
    load_profile "${profile_name}"

    load_recipe linux
    build_package linux

    if [[ -f /mnt/boot/vmlinuz-linux-custom ]]; then
        log_info "Custom kernel rebuilt successfully."
        artix-chroot /mnt mkinitcpio -P 2>/dev/null || log_warn "mkinitcpio failed"
        artix-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || log_warn "grub-mkconfig failed"
    else
        log_error "Kernel rebuild may have failed – check logs."
    fi
}

repair_system() {
    repair_fstab
    repair_pacman
    repair_boot
    repair_kernel
    if [[ -x /mnt/usr/bin/mkinitcpio ]]; then
        artix-chroot /mnt mkinitcpio -P 2>/dev/null || log_warn "mkinitcpio failed"
    fi
    log_info "Repair complete. You may now reboot."
}

detect_rootkits() {
    if ! command -v rkhunter &>/dev/null; then
        pacman -S --noconfirm rkhunter
    fi
    rkhunter --check --skip-keypress 2>&1 | tee /tmp/rkhunter.log
    if grep -q 'Warning' /tmp/rkhunter.log; then
        log_warn "Rootkit warnings found. Review /tmp/rkhunter.log"
    else
        log_info "No rootkit warnings detected."
    fi
}