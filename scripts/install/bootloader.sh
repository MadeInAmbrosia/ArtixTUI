#!/usr/bin/env bash
set -Eeuo pipefail

configure_bootloader() {
    local bootloader kernel fs_type root_param=''
    bootloader="$(state_get BOOTLOADER grub)"
    kernel="$(state_get KERNEL_CHOICE linux)"
    fs_type="$(state_get FS_TYPE)"
    [[ "${fs_type}" == 'zfs' ]] && root_param='root=ZFS=zroot/root'

    log_info "Generating initramfs..."
    artix-chroot /mnt mkinitcpio -P || true
    if ! compgen -G "/mnt/boot/initramfs-*.img" >/dev/null 2>&1; then
        recoverable_error 'No initramfs image was created – updating ArtixForge may fix this'
    fi
    log_info "Initramfs generation complete"

    local root_device
    root_device=$(artix-chroot /mnt findmnt -n -o SOURCE /) || true
    root_device="${root_device%%[*}"
    [[ -n "${root_device}" ]] || die 'failed to detect root device'

    local root_source root_uuid esp_source esp_mount esp_disk esp_part
    root_source="$(findmnt -rn -o SOURCE --target /mnt)"
    root_source="${root_source%%[*}"
    [[ -n "${root_source}" ]] || die 'failed to detect root partition'
    [[ -b "${root_source}" ]] || die 'invalid root block device'
    root_uuid="$(blkid -s UUID -o value "${root_source}")"
    [[ -n "${root_uuid}" ]] || die 'failed to detect root UUID'

    local crypt_uuid="${root_uuid}"
    if [[ "$(state_get USE_LVM no)" == "yes" && "$(state_get USE_LUKS no)" == "yes" ]]; then
        local raw_part
        raw_part="$(lsblk -no PKNAME "${root_source}" 2>/dev/null || true)"
        if [[ -n "${raw_part}" ]]; then
            crypt_uuid="$(blkid -s UUID -o value "/dev/${raw_part}" 2>/dev/null || echo "${root_uuid}")"
        fi
    fi

    for esp_mount in /mnt/boot/efi /mnt/efi /mnt/boot; do
        if findmnt -rn -o FSTYPE "${esp_mount}" | grep -qx 'vfat'; then
            esp_source="$(findmnt -rn -o SOURCE "${esp_mount}")"
            break
        fi
    done
    [[ -n "${esp_source}" ]] || die 'failed to detect EFI partition'
    log_info "EFI partition mount: ${esp_mount}"
    esp_disk="/dev/$(lsblk -no PKNAME "${esp_source}" | head -n1)"
    esp_part="$(lsblk -no PARTN "${esp_source}" | head -n1)"
    [[ -n "${esp_part}" ]] || die 'failed to detect EFI partition number'

    if [[ "$(state_get GENERATE_UKI no)" == "yes" ]]; then
        log_info "Configuring UKI generation..."
        local uki_kernel_image uki_kernel_name uki_kver
        uki_kernel_image=$(ls /mnt/boot/vmlinuz-* 2>/dev/null | head -n1)
        [[ -n "${uki_kernel_image}" ]] || die "No kernel image found for UKI"
        uki_kernel_name=$(basename "${uki_kernel_image}")
        uki_kver="${uki_kernel_name#vmlinuz-}"
        local uki_initramfs_name="initramfs-${uki_kver}.img"
        local uki_output="${esp_mount#/mnt}/EFI/Linux/artix-${uki_kver}.efi"
        artix-chroot /mnt mkdir -p /boot/efi/EFI/Linux

        if [[ -x /mnt/usr/bin/ukify ]]; then
            log_info "Generating UKI with ukify..."
            artix-chroot /mnt /usr/bin/ukify build \
                --linux="/boot/${uki_kernel_name}" \
                --initrd="/boot/${uki_initramfs_name}" \
                --cmdline="root=UUID=${root_uuid} rw cryptdevice=UUID=${crypt_uuid}:cryptroot" \
                --output="${uki_output}" || die "ukify failed — UKI not generated"
        else
            die "ukify not found — install eukify package for UKI support"
        fi
    fi

    case "${bootloader}" in
        grub)
            log_info "Installing GRUB..."
            findmnt -rn -o FSTYPE /mnt/boot/efi | grep -qx 'vfat' || die 'EFI partition not mounted as vfat'

            if [[ "${fs_type}" == "xfs" ]]; then
                log_info "Verifying XFS features for GRUB compatibility..."
                if artix-chroot /mnt xfs_info "${root_device}" 2>/dev/null | grep -q 'bigtime=1'; then
                    die "XFS bigtime is enabled and may be incompatible with older GRUB builds."
                fi
            fi

            artix-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ARTIX || recoverable_error 'grub-install failed – updating ArtixForge may help'
            if [[ -n "${root_param}" ]]; then
                artix-chroot /mnt sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"${root_param}\"|" /etc/default/grub
            fi
            log_info "Generating GRUB configuration..."
            artix-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg || recoverable_error 'grub-mkconfig failed – updating ArtixForge may fix this'
            ;;
        refind)
            log_info "Installing rEFInd..."
            findmnt -rn -o FSTYPE /mnt/boot/efi | grep -qx 'vfat' || die 'EFI partition not mounted as vfat'
            local refind_root_param
            if [[ -n "${root_param}" ]]; then
                refind_root_param="${root_param}"
            else
                local refind_root_device refind_root_uuid
                refind_root_device=$(findmnt -n -o SOURCE --target /mnt)
                refind_root_device="${refind_root_device%%[*]}"
                refind_root_uuid=$(blkid -s UUID -o value "${refind_root_device}")
                refind_root_param="root=UUID=${refind_root_uuid}"
            fi
            artix-chroot /mnt bash -c "echo \"${refind_root_param} rw\" > /boot/refind_linux.conf"
            artix-chroot /mnt refind-install || die 'refind-install failed'
            ;;
        efistub)
            log_info "Configuring EFIStub boot entry..."
            command -v efibootmgr >/dev/null 2>&1 || die 'efibootmgr unavailable'

            local kernel_image initramfs_image microcode_file
            kernel_image=$(ls /mnt/boot/vmlinuz-* 2>/dev/null | head -n1)
            [[ -n "${kernel_image}" ]] || die 'failed to locate kernel image'
            initramfs_image=$(ls /mnt/boot/initramfs-*.img 2>/dev/null | grep -v fallback | head -n1)
            [[ -n "${initramfs_image}" ]] || die 'failed to locate initramfs image'
            microcode_file="$(state_get MICROCODE_IMAGE)"

            local kernel_basename initramfs_basename microcode_image_str
            kernel_basename="$(basename "${kernel_image}")"
            initramfs_basename="$(basename "${initramfs_image}")"
            local esp_artix_dir="${esp_mount}/EFI/Artix"
            mkdir -p "${esp_artix_dir}"
            cp -f "${kernel_image}" "${esp_artix_dir}/${kernel_basename}"
            cp -f "${initramfs_image}" "${esp_artix_dir}/${initramfs_basename}"

            if [[ -n "${microcode_file}" && -f "/mnt/boot/${microcode_file}" ]]; then
                cp -f "/mnt/boot/${microcode_file}" "${esp_artix_dir}/${microcode_file}"
                microcode_image_str="initrd=\\EFI\\Artix\\${microcode_file}"
            fi

            local loader="\\EFI\\Artix\\${kernel_basename}"
            local cmdline
            if [[ "${fs_type}" == 'zfs' ]]; then
                cmdline="root=ZFS=zroot/root rw"
            else
                cmdline="root=UUID=${root_uuid} rw"
            fi
            [[ -n "${microcode_image_str:-}" ]] && cmdline+=" ${microcode_image_str}"
            cmdline+=" initrd=\\EFI\\Artix\\${initramfs_basename}"

            if [[ "$(state_get USE_LUKS no)" == "yes" ]]; then
                cmdline+=" cryptdevice=UUID=${crypt_uuid}:cryptroot"
            fi
            if [[ "$(state_get USE_LVM no)" == "yes" ]]; then
                cmdline+=" root=/dev/vg0/root"
            fi

            log_info "Creating EFI boot entry..."
            artix-chroot /mnt efibootmgr --create --disk "${esp_disk}" --part "${esp_part}" \
                --label 'Artix Linux' --loader "${loader}" --unicode "${cmdline}" --verbose \
                || die 'failed to create EFI boot entry'

            log_info "Verifying EFI boot entries..."
            artix-chroot /mnt efibootmgr -v | grep -qi 'Artix Linux' || die "failed to verify EFI boot entry"
            ;;
        limine)
            log_info "Installing Limine..."
            findmnt -rn -o FSTYPE /mnt/boot/efi | grep -qx 'vfat' || die 'EFI partition not mounted as vfat'

            artix-chroot /mnt pacman -S --noconfirm limine || die "Failed to install limine"

            mkdir -p /mnt/boot/efi/EFI/BOOT
            if ! cp /mnt/usr/share/limine/BOOTX64.EFI /mnt/boot/efi/EFI/BOOT/ 2>/dev/null; then
                die "Failed to copy BOOTX64.EFI — Limine may not be properly installed"
            fi
            log_info "Limine EFI binary installed to /boot/efi/EFI/BOOT/"

            local limine_kernel limine_initramfs limine_microcode
            limine_kernel=$(ls /mnt/boot/vmlinuz-* 2>/dev/null | head -n1)
            [[ -n "${limine_kernel}" ]] || die 'No kernel image found'
            limine_initramfs=$(ls /mnt/boot/initramfs-*.img 2>/dev/null | grep -v fallback | head -n1)
            [[ -n "${limine_initramfs}" ]] || log_warn 'No initramfs image found'
            limine_microcode="$(state_get MICROCODE_IMAGE)"

            local limine_kernel_name limine_initramfs_name
            limine_kernel_name="$(basename "${limine_kernel}")"
            limine_initramfs_name="$(basename "${limine_initramfs}")"

            local limine_root_cmdline
            if [[ "${fs_type}" == 'zfs' ]]; then
                limine_root_cmdline="root=ZFS=zroot/root rw modules=zfs rootfstype=zfs"
            else
                limine_root_cmdline="root=UUID=${root_uuid} rw"
            fi

            case "${fs_type}" in
                btrfs) limine_root_cmdline+=" rootfstype=btrfs" ;;
                xfs)   limine_root_cmdline+=" rootfstype=xfs" ;;
                f2fs)  limine_root_cmdline+=" rootfstype=f2fs" ;;
            esac

            if [[ "$(state_get USE_LUKS no)" == "yes" ]]; then
                limine_root_cmdline+=" cryptdevice=UUID=${crypt_uuid}:cryptroot"
            fi
            if [[ "$(state_get USE_LVM no)" == "yes" ]]; then
                limine_root_cmdline+=" root=/dev/vg0/root"
            fi

            log_info "Writing ${esp_mount}/limine.conf..."
            cat > "${esp_mount}/limine.conf" <<LIMINE_EOF
timeout: 5

/Linux
    protocol: linux
    kernel_path: boot():/${limine_kernel_name}
LIMINE_EOF

            if [[ -n "${limine_microcode}" && -f "/mnt/boot/${limine_microcode}" ]]; then
                cat >> "${esp_mount}/limine.conf" <<LIMINE_EOF
    module_path: boot():/${limine_microcode}
LIMINE_EOF
            fi

            cat >> "${esp_mount}/limine.conf" <<LIMINE_EOF
    module_path: boot():/${limine_initramfs_name}
    cmdline: ${limine_root_cmdline}
    comment: Boot Artix Linux
LIMINE_EOF

            if [[ "${fs_type}" == "btrfs" && "$(state_get BTRFS_LAYOUT standard)" == "snapshot" ]]; then
                if [[ -d /mnt/.snapshots ]]; then
                    log_info "BTRFS snapshot layout detected — generating snapshot boot entries..."
                    local snapshot
                    for snapshot in $(ls -1t /mnt/.snapshots/ 2>/dev/null | head -n5); do
                        local snap_path="/mnt/.snapshots/${snapshot}/snapshot"
                        [[ -d "${snap_path}" ]] || continue
                        cat >> "${esp_mount}/limine.conf" <<LIMINE_EOF

/Snapshot: ${snapshot}
    protocol: linux
    kernel_path: boot():/${limine_kernel_name}
LIMINE_EOF
                        if [[ -n "${limine_microcode}" && -f "/mnt/boot/${limine_microcode}" ]]; then
                            cat >> "${esp_mount}/limine.conf" <<LIMINE_EOF
    module_path: boot():/${limine_microcode}
LIMINE_EOF
                        fi
                        cat >> "${esp_mount}/limine.conf" <<LIMINE_EOF
    module_path: boot():/${limine_initramfs_name}
    cmdline: ${limine_root_cmdline} rootflags=subvol=.snapshots/${snapshot}/snapshot
    comment: Boot into snapshot ${snapshot}
LIMINE_EOF
                    done
                fi
            fi

            if [[ -f /mnt/boot/efi/EFI/Microsoft/Boot/bootmgfw.efi ]]; then
                cat >> "${esp_mount}/limine.conf" <<'LIMINE_EOF'

/Windows
    protocol: efi
    path: boot():/EFI/Microsoft/Boot/bootmgfw.efi
    comment: Boot Windows
LIMINE_EOF
                log_info "Windows boot entry added to limine.conf"
            fi

            log_info "Creating Limine EFI boot entry..."
            artix-chroot /mnt efibootmgr --create --disk "${esp_disk}" --part "${esp_part}" \
                --label 'Limine' --loader '\EFI\BOOT\BOOTX64.EFI' --verbose \
                || log_warn "Failed to create Limine EFI boot entry — you may need to select it from your UEFI firmware menu"

            log_info "Limine installed successfully."
            ;;
        *)
            die "unsupported bootloader: ${bootloader}" ;;
    esac

    if [[ "$(state_get GENERATE_UKI no)" == "yes" ]]; then
        local uki_file="${esp_mount}/EFI/Linux/artix-${uki_kver}.efi"
        if [[ -f "${uki_file}" ]]; then
            log_info "Creating EFI boot entry for UKI..."
            artix-chroot /mnt efibootmgr --create --disk "${esp_disk}" --part "${esp_part}" \
                --label 'Artix Linux (UKI)' \
                --loader "\\EFI\\Linux\\artix-${uki_kver}.efi" \
                --unicode "root=UUID=${root_uuid} rw cryptdevice=UUID=${crypt_uuid}:cryptroot" --verbose \
                || die "Failed to create UKI EFI boot entry"

            if tui_yesno "Secure Boot" "Sign the UKI for Secure Boot?"; then
                local sb_key sb_cert
                sb_key=$(tui_input "Secure Boot" "Path to DB.key (on target):" "/etc/secureboot/DB.key")
                sb_cert=$(tui_input "Secure Boot" "Path to DB.crt (on target):" "/etc/secureboot/DB.crt")
                if [[ -f "/mnt${sb_key}" && -f "/mnt${sb_cert}" ]]; then
                    artix-chroot /mnt sbsign --key "${sb_key}" --cert "${sb_cert}" \
                        --output "${esp_mount}/EFI/Linux/artix-${uki_kver}-signed.efi" \
                        "${esp_mount}/EFI/Linux/artix-${uki_kver}.efi" || die "sbsign failed"
                    artix-chroot /mnt efibootmgr --create --disk "${esp_disk}" --part "${esp_part}" \
                        --label 'Artix Linux (UKI Signed)' \
                        --loader "\\EFI\\Linux\\artix-${uki_kver}-signed.efi" \
                        --unicode "root=UUID=${root_uuid} rw cryptdevice=UUID=${crypt_uuid}:cryptroot" --verbose \
                        || log_warn "Failed to create signed UKI boot entry"
                    log_info "UKI signed for Secure Boot."
                else
                    log_warn "Signing keys not found at /mnt${sb_key} and /mnt${sb_cert}"
                fi
            fi
        else
            die "UKI generation failed — ${uki_file} was not created."
        fi
    fi

    log_info "Bootloader setup complete."
}