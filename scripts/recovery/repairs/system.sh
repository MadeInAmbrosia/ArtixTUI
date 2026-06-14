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

_kernel_pkg() {
    local choice="${1:-linux}"
    case "${choice}" in
        linux)                echo "linux linux-headers" ;;
        linux-zen)            echo "linux-zen linux-zen-headers" ;;
        linux-lts)            echo "linux-lts linux-lts-headers" ;;
        linux-hardened)       echo "linux-hardened linux-hardened-headers" ;;
        linux-libre)          echo "linux-libre linux-libre-headers" ;;
        linux-cachyos-bore)   echo "linux-cachyos-bore linux-cachyos-bore-headers" ;;
        linux-bazzite-bin)    echo "linux-bazzite-bin linux-bazzite-bin-headers" ;;
        xanmod)               echo "linux-xanmod linux-xanmod-headers" ;;
        tkg)                  echo "" ;;
        linux-custom)         echo "" ;;
        *)                    echo "linux linux-headers" ;;
    esac
}

repair_boot() {
    local issues
    issues=$(state_get BOOT_ISSUES none)

    if [[ "${issues}" =~ no-kernel ]]; then
        log_warn "Kernel image missing from /boot."
        local kernel_choice kernel_pkgs
        kernel_choice=$(state_get KERNEL_CHOICE linux)
        kernel_pkgs=$(_kernel_pkg "${kernel_choice}")
        if [[ -n "${kernel_pkgs}" ]]; then
            if tui_yesno "Reinstall kernel" "Reinstall ${kernel_choice} kernel?"; then
                artix-chroot /mnt pacman -S --noconfirm ${kernel_pkgs}
            fi
        else
            log_warn "No binary package for kernel ${kernel_choice} — skipping."
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
        local bootloader
        bootloader=$(state_get BOOTLOADER grub)
        if tui_yesno "Reinstall bootloader" "Reinstall ${bootloader}?"; then
            case "${bootloader}" in
                grub)
                    artix-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ARTIX
                    artix-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
                    ;;
                limine)
                    artix-chroot /mnt pacman -S --noconfirm limine
                    mkdir -p /mnt/boot/efi/EFI/BOOT
                    cp /mnt/usr/share/limine/BOOTX64.EFI /mnt/boot/efi/EFI/BOOT/
                    local esp_disk esp_part
                    esp_disk="$(lsblk -no PKNAME "$(findmnt -no SOURCE /mnt/boot/efi 2>/dev/null)" 2>/dev/null || true)"
                    esp_part="$(lsblk -no PARTN "$(findmnt -no SOURCE /mnt/boot/efi 2>/dev/null)" 2>/dev/null || true)"
                    if [[ -n "${esp_disk}" && -n "${esp_part}" ]]; then
                        artix-chroot /mnt efibootmgr --create --disk "/dev/${esp_disk}" --part "${esp_part}" \
                            --label 'Limine' --loader '\EFI\BOOT\BOOTX64.EFI' --verbose || true
                    else
                        log_warn "Could not detect EFI partition — skipping EFI entry creation"
                    fi
                    ;;
                refind)
                    artix-chroot /mnt refind-install
                    ;;
                efistub)
                    log_warn "EFIStub repair not implemented — please re-run the installer or manually configure."
                    ;;
            esac
        fi
    fi

    if [[ "${issues}" =~ no-uki ]]; then
        log_warn "UKI file missing."
        repair_uki
    fi

    if [[ "${issues}" =~ missing-cryptdevice ]]; then
        log_warn "Bootloader config is missing cryptdevice= parameter."
        if tui_yesno "Repair cmdline" "Regenerate bootloader configuration with correct cryptdevice?"; then
            source "${SCRIPT_DIR}/install/bootloader.sh"
            configure_bootloader
        fi
    fi

    if [[ "${issues}" =~ missing-encrypt-hook ]]; then
        log_warn "mkinitcpio.conf is missing the encrypt hook."
        if tui_yesno "Repair hooks" "Add encrypt hook to mkinitcpio.conf and regenerate initramfs?"; then
            artix-chroot /mnt sed -i 's/\(block\)/\1 encrypt/' /etc/mkinitcpio.conf
            artix-chroot /mnt mkinitcpio -P
        fi
    fi
}

repair_uki() {
    if [[ "$(state_get GENERATE_UKI no)" != "yes" ]]; then
        return 0
    fi

    local uki_dir="/mnt/boot/efi/EFI/Linux"
    local uki_file=""

    if [[ -d "${uki_dir}" ]]; then
        uki_file=$(compgen -G "${uki_dir}/artix-*.efi" 2>/dev/null | head -n1)
    fi

    if [[ -z "${uki_file}" ]]; then
        log_warn "UKI is enabled but no UKI file found."
        if tui_yesno "Repair UKI" "Regenerate UKI and EFI boot entry?"; then
            if ! artix-chroot /mnt command -v ukify &>/dev/null; then
                log_warn "ukify not found — install eukify package first"
                return 1
            fi
            source "${SCRIPT_DIR}/install/bootloader.sh"
            configure_bootloader
        fi
    else
        log_info "UKI found: ${uki_file}"
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
        if [[ -d /mnt/boot/grub ]]; then
            artix-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || log_warn "grub-mkconfig failed"
        fi
    else
        log_error "Kernel rebuild may have failed – check logs."
    fi
}