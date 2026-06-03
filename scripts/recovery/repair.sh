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
    if ! artix-chroot /mnt true &>/dev/null; then
        log_warn "Chroot environment not available — skipping pacman repairs"
        return 0
    fi

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
                pacman --root /mnt --cachedir /mnt/var/cache/pacman/pkg -S --noconfirm base base-devel 2>/dev/null || \
                    log_warn "Base reinstall failed. Try 'Fix everything' from the recovery menu."
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
                log_info "Reinstalling ${count} broken packages..."
                local -a pkgs
                read -ra pkgs <<< "${broken_list}"
                local batch=() i=0 success=0 fail=0
                for pkg in "${pkgs[@]}"; do
                    batch+=("${pkg}")
                    ((i++))
                    if [[ ${i} -ge 20 ]]; then
                        log_info "  Batch: ${batch[*]}"
                        if pacman --root /mnt --cachedir /mnt/var/cache/pacman/pkg -S --noconfirm --overwrite '*' "${batch[@]}" 2>/dev/null; then
                            ((success += i))
                        else
                            log_warn "  Batch failed — trying individually..."
                            for b in "${batch[@]}"; do
                                if pacman --root /mnt -S --noconfirm --overwrite '*' "${b}" 2>/dev/null; then
                                    ((success++))
                                else
                                    log_warn "  Failed: ${b}"
                                    ((fail++))
                                fi
                            done
                        fi
                        batch=() i=0
                    fi
                done

                if [[ ${#batch[@]} -gt 0 ]]; then
                    log_info "  Final batch: ${batch[*]}"
                    if pacman --root /mnt --cachedir /mnt/var/cache/pacman/pkg -S --noconfirm --overwrite '*' "${batch[@]}" 2>/dev/null; then
                        ((success += ${#batch[@]}))
                    else
                        for b in "${batch[@]}"; do
                            if pacman --root /mnt -S --noconfirm --overwrite '*' "${b}" 2>/dev/null; then
                                ((success++))
                            else
                                log_warn "  Failed: ${b}"
                                ((fail++))
                            fi
                        done
                    fi
                fi
                log_info "Reinstall complete: ${success} succeeded, ${fail} failed"
            else
                log_info "No broken package list saved — skipping"
            fi
            log_info "Broken package repair completed."
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
        if tui_yesno "Repair UKI" "Regenerate UKI with ukify?"; then
            if ! artix-chroot /mnt command -v ukify &>/dev/null; then
                log_warn "ukify not found — install eukify package first"
                return 1
            fi
            local kernel_version initramfs_name root_uuid
            kernel_version=$(ls /mnt/boot/vmlinuz-* 2>/dev/null | head -n1 | sed 's/.*vmlinuz-//')
            initramfs_name="initramfs-${kernel_version}.img"
            root_uuid=$(findmnt -n -o UUID /mnt 2>/dev/null || blkid -s UUID -o value "$(findmnt -n -o SOURCE /mnt)")
            mkdir -p /mnt/boot/efi/EFI/Linux
            artix-chroot /mnt ukify build \
                --linux="/boot/vmlinuz-${kernel_version}" \
                --initrd="/boot/${initramfs_name}" \
                --cmdline="root=UUID=${root_uuid} rw" \
                --output="/boot/efi/EFI/Linux/artix-${kernel_version}.efi" || {
                    log_error "ukify failed — UKI not regenerated"
                    return 1
                }
            log_info "UKI regenerated successfully."
        fi
    else
        log_info "UKI found: ${uki_file}"
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
        tkg)                  echo "" ;;  # TKG is built from source, not a binary package
        linux-custom)         echo "" ;;  # Custom Power User kernel, handled separately
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
                    artix-chroot /mnt efibootmgr --create --disk "${esp_disk}" --part "${esp_part}" \
                        --label 'Limine' --loader '\EFI\BOOT\BOOTX64.EFI' --verbose || true
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