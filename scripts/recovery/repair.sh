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
            if ! basestrap /mnt base base-devel 2>/dev/null; then
                log_warn "basestrap failed — trying direct pacman install..."
                pacman --root /mnt --cachedir /mnt/var/cache/pacman/pkg -S --noconfirm base base-devel 2>/dev/null || {
                    log_error "Base reinstall failed. Try 'Fix everything' from the recovery menu."
                }
            fi
            log_info "Base packages reinstalled."
        fi
    fi

    if [[ "${issues}" =~ broken-pkgs:([0-9]+) ]]; then
        local count="${BASH_REMATCH[1]}"
        log_warn "${count} packages have missing files."
        if tui_yesno "Repair broken packages" "Reinstall all packages with missing files? This may take a while."; then
            local broken_list
            broken_list="$(state_get BROKEN_PACKAGES "")"
            if [[ -n "${broken_list}" ]]; then
                log_info "Reinstalling: ${broken_list}"
                pacman --root /mnt --cachedir /mnt/var/cache/pacman/pkg -S --noconfirm ${broken_list} 2>/dev/null || {
                    log_warn "Bulk reinstall failed — attempting one-by-one"
                    for pkg in ${broken_list}; do
                        pacman --root /mnt -S --noconfirm "${pkg}" 2>/dev/null || log_warn "Failed to reinstall ${pkg}"
                    done
                }
            fi
            log_info "Broken package repair completed."
        fi
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

repair_detected_issues() {
    local fstab_issues boot_issues pacman_issues
    fstab_issues=$(state_get FSTAB_ISSUES none)
    boot_issues=$(state_get BOOT_ISSUES none)
    pacman_issues=$(state_get PACMAN_ISSUES none)

    local did_something=0

    if [[ "${fstab_issues}" != "none" ]]; then
        log_info "FSTAB issues detected: ${fstab_issues}"
        repair_fstab
        did_something=1
    fi

    if [[ "${pacman_issues}" != "none" ]]; then
        log_info "Pacman issues detected: ${pacman_issues}"
        repair_pacman
        did_something=1
    fi

    if [[ "${boot_issues}" != "none" ]]; then
        log_info "Boot issues detected: ${boot_issues}"
        repair_boot
        did_something=1
    fi

    if [[ ${did_something} -eq 1 ]]; then
        if [[ "${boot_issues}" =~ no-initramfs || "${boot_issues}" =~ no-kernel ]] || \
           [[ "${fstab_issues}" != "none" ]]; then
            if [[ -x /mnt/usr/bin/mkinitcpio ]]; then
                log_info "Regenerating initramfs..."
                artix-chroot /mnt mkinitcpio -P 2>/dev/null || log_warn "mkinitcpio failed"
            fi
        fi

        # Regenerate GRUB config if boot was touched
        if [[ "${boot_issues}" != "none" ]] && [[ -d /mnt/boot/grub ]]; then
            log_info "Regenerating GRUB config..."
            artix-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || log_warn "grub-mkconfig failed"
        fi
    else
        log_info "No issues detected — nothing to repair."
    fi

    log_info "Repair complete."
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

repair_system() {
    log_info "Running full system repair (nuclear option)..."
    repair_fstab
    repair_pacman
    repair_boot
    repair_kernel
    if [[ -x /mnt/usr/bin/mkinitcpio ]]; then
        artix-chroot /mnt mkinitcpio -P 2>/dev/null || log_warn "mkinitcpio failed"
    fi
    if [[ -d /mnt/boot/grub ]]; then
        artix-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || log_warn "grub-mkconfig failed"
    fi
    log_info "Full repair complete."
}

untrusted_recovery() {
    tui_msg "Untrusted Recovery" \
"This is a DANGEROUS operation intended for systems you
believe may be compromised.

What it will do:
  • Run a rootkit scan (rkhunter)
  • Check for common malware indicators
  • Optionally scan with ClamAV

It will NOT modify your filesystem or attempt repairs.
You run this AT YOUR OWN RISK.

Proceed?"

    if ! tui_yesno "Untrusted Recovery" "Are you absolutely sure?"; then
        log_info "Untrusted recovery cancelled."
        return 0
    fi

    log_info "Running rootkit scan..."
    if ! command -v rkhunter >/dev/null; then
        pacman -S --noconfirm rkhunter
    fi
    rkhunter --check --skip-keypress --report-warnings-only 2>&1 | tee /tmp/rkhunter-untrusted.log
    if grep -q 'Warning' /tmp/rkhunter-untrusted.log; then
        log_warn "Rootkit warnings found. Review /tmp/rkhunter-untrusted.log"
    else
        log_info "No rootkit warnings detected."
    fi

    log_info "Checking for common malware indicators..."
    local indicators=0
    if [[ -d /mnt/etc/cron.d ]]; then
        if grep -rl 'wget\|curl.*|.*sh' /mnt/etc/cron.* /mnt/var/spool/cron 2>/dev/null; then
            log_warn "Suspicious cron entries found (wget/curl piped to shell)"
            indicators=1
        fi
    fi
    if [[ -d /mnt/etc/systemd/system ]]; then
        if grep -rl 'ExecStart=.*/tmp/' /mnt/etc/systemd/system 2>/dev/null; then
            log_warn "Systemd services executing from /tmp found"
            indicators=1
        fi
    fi
    if [[ -f /mnt/root/.ssh/authorized_keys ]]; then
        if grep -q 'ssh-rsa' /mnt/root/.ssh/authorized_keys 2>/dev/null; then
            log_info "Root SSH keys present — ensure you recognize them"
        fi
    fi
    local suid_check
    suid_check=$(find /mnt/usr/bin /mnt/bin /mnt/sbin -type f -perm -4000 -perm -o+w 2>/dev/null)
    if [[ -n "${suid_check}" ]]; then
        log_warn "World-writable SUID binaries found:"
        printf '%s\n' "${suid_check}" | tee -a /tmp/untrusted-recovery.log
        indicators=1
    fi

    if [[ ${indicators} -eq 0 ]]; then
        log_info "No common malware indicators found."
    fi

    if tui_yesno "Malware Scan" "Run ClamAV scan on the installation? (requires ClamAV)"; then
        if ! command -v clamscan >/dev/null; then
            log_info "Installing ClamAV..."
            pacman -S --noconfirm clamav
            freshclam --quiet || log_warn "ClamAV database update failed"
        fi
        log_info "Scanning /mnt with ClamAV (this may take a long time)..."
        clamscan -r --bell --max-filesize=100M --max-scansize=100M /mnt 2>&1 | tee /tmp/clamav-untrusted.log
        if grep -q 'FOUND' /tmp/clamav-untrusted.log; then
            log_warn "ClamAV found potential threats. Review /tmp/clamav-untrusted.log"
        else
            log_info "ClamAV scan clean."
        fi
    fi

    log_info "Untrusted recovery scans complete."
    tui_msg "Untrusted Recovery" \
"Scans complete. Review logs in /tmp:
  rkhunter-untrusted.log
  clamav-untrusted.log (if run)
  untrusted-recovery.log

If threats were found, consider reinstalling from a
trusted ISO rather than repairing."
}

repair_filesystem() {
    local root_part fs_type
    root_part="$(findmnt -no SOURCE /mnt 2>/dev/null || true)"
    fs_type="$(state_get FS_TYPE ext4)"

    if [[ -z "${root_part}" || ! -b "${root_part}" ]]; then
        log_error "Could not determine root partition — is /mnt mounted?"
        return 1
    fi

    tui_msg "Filesystem Repair" \
"Filesystem: ${fs_type} on ${root_part}

This will attempt to repair filesystem corruption.
You can choose:
  • Safe – non-destructive check and repair
  • Destructive – aggressive repair, may discard data

Always back up your data first."

    local method
    method=$(tui_menu "Repair Method" "Select repair approach:" \
        "Safe (fsck -p / equivalent)" \
        "Destructive (fsck -f -y / equivalent)" \
        "Cancel") || return 1

    if [[ "${method}" == "Cancel" ]]; then
        return 0
    fi

    log_info "Unmounting /mnt for filesystem check..."
    umount /mnt 2>/dev/null || { log_error "Failed to unmount /mnt — something is using it"; return 1; }

    case "${fs_type}" in
        ext4)
            if [[ "${method}" == Safe* ]]; then
                log_info "Running safe fsck.ext4 -p on ${root_part}..."
                fsck.ext4 -p "${root_part}" || log_warn "fsck reported errors (safe mode)"
            else
                log_info "Running destructive fsck.ext4 -f -y on ${root_part}..."
                fsck.ext4 -f -y "${root_part}" || log_warn "fsck reported errors (destructive mode)"
            fi
            ;;
        btrfs)
            if [[ "${method}" == Safe* ]]; then
                log_info "Running btrfs check (read-only) on ${root_part}..."
                btrfs check "${root_part}" || log_warn "btrfs check found issues"
            else
                log_warn "btrfs check --repair can make corruption worse."
                if tui_yesno "DANGER" "Really run btrfs check --repair? This may destroy data."; then
                    btrfs check --repair "${root_part}" || log_warn "btrfs repair attempted"
                fi
            fi
            ;;
        xfs)
            if [[ "${method}" == Safe* ]]; then
                log_info "Running xfs_repair -n (dry-run) on ${root_part}..."
                xfs_repair -n "${root_part}" || log_warn "xfs_repair -n found issues"
            else
                log_info "Running xfs_repair on ${root_part}..."
                xfs_repair "${root_part}" || log_warn "xfs_repair reported errors"
            fi
            ;;
        *)
            log_warn "Filesystem repair not supported for ${fs_type}"
            mount "${root_part}" /mnt || die "Failed to remount after repair attempt"
            return 1
            ;;
    esac

    log_info "Remounting ${root_part} to /mnt..."
    mount "${root_part}" /mnt || die "Failed to remount after repair"

    if tui_yesno "Post-Repair" "Would you like to run standard system repair (fstab, boot, etc.)?"; then
        repair_detected_issues
    fi

    log_info "Filesystem repair complete."
}