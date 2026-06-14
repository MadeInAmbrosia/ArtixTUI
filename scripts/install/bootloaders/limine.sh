#!/usr/bin/env bash
set -Eeuo pipefail

bootloader_install_limine() {
    log_info "Installing Limine..."
    findmnt -rn -o FSTYPE /mnt/boot/efi | grep -qx 'vfat' || die 'EFI partition not mounted as vfat'

    artix-chroot /mnt pacman -S --noconfirm limine || die "Failed to install limine"

    mkdir -p /mnt/boot/efi/EFI/BOOT
    if ! cp /mnt/usr/share/limine/BOOTX64.EFI /mnt/boot/efi/EFI/BOOT/ 2>/dev/null; then
        die "Failed to copy BOOTX64.EFI — Limine may not be properly installed"
    fi
    log_info "Limine EFI binary installed to /boot/efi/EFI/BOOT/"

    local limine_microcode
    limine_microcode="$(state_get MICROCODE_IMAGE)"

    local limine_root_cmdline=""
    if [[ "${fs_type}" == 'zfs' ]]; then
        limine_root_cmdline="root=ZFS=zroot/root rw modules=zfs rootfstype=zfs"
    else
        if [[ "$(state_get USE_LUKS no)" == "yes" ]]; then
            limine_root_cmdline+="cryptdevice=UUID=${crypt_uuid}:${mapper_name} "
        fi
        if [[ "$(state_get USE_LVM no)" == "yes" ]]; then
            limine_root_cmdline+="root=/dev/vg0/root "
        elif [[ "$(state_get USE_LUKS no)" == "yes" ]]; then
            limine_root_cmdline+="root=/dev/mapper/${mapper_name} "
        else
            limine_root_cmdline+="root=UUID=${root_uuid} "
        fi
        limine_root_cmdline+="rw"
    fi

    case "${fs_type}" in
        btrfs) limine_root_cmdline+=" rootfstype=btrfs" ;;
        xfs)   limine_root_cmdline+=" rootfstype=xfs" ;;
        f2fs)  limine_root_cmdline+=" rootfstype=f2fs" ;;
    esac

    log_info "Writing ${esp_mount}/limine.conf..."
    cat > "${esp_mount}/limine.conf" <<LIMINE_EOF
timeout: 5

LIMINE_EOF

    local found_kernel=0
    local limine_kernel
    for limine_kernel in /mnt/boot/vmlinuz-*; do
        [[ -f "${limine_kernel}" ]] || continue
        found_kernel=1
        local limine_kernel_name limine_initramfs limine_initramfs_name
        limine_kernel_name="$(basename "${limine_kernel}")"
        local kver="${limine_kernel_name#vmlinuz-}"

        limine_initramfs=$(ls /mnt/boot/initramfs-${kver}.img 2>/dev/null | head -n1)
        if [[ -z "${limine_initramfs}" ]]; then
            limine_initramfs=$(ls /mnt/boot/initramfs-*.img 2>/dev/null | grep -v fallback | head -n1)
        fi
        [[ -n "${limine_initramfs}" ]] && limine_initramfs_name="$(basename "${limine_initramfs}")"

        cat >> "${esp_mount}/limine.conf" <<LIMINE_EOF
/Artix (${kver})
    protocol: linux
    kernel_path: boot():/${limine_kernel_name}
LIMINE_EOF

        if [[ -n "${limine_microcode}" && -f "/mnt/boot/${limine_microcode}" ]]; then
            cat >> "${esp_mount}/limine.conf" <<LIMINE_EOF
    module_path: boot():/${limine_microcode}
LIMINE_EOF
        fi

        if [[ -n "${limine_initramfs_name:-}" ]]; then
            cat >> "${esp_mount}/limine.conf" <<LIMINE_EOF
    module_path: boot():/${limine_initramfs_name}
LIMINE_EOF
        fi

        cat >> "${esp_mount}/limine.conf" <<LIMINE_EOF
    cmdline: ${limine_root_cmdline}
    comment: Boot Artix Linux (${kver})
LIMINE_EOF

        if [[ "${fs_type}" == "btrfs" && "$(state_get BTRFS_LAYOUT standard)" == "snapshot" ]]; then
            if [[ -d /mnt/.snapshots ]]; then
                local snapshot
                for snapshot in $(ls -1t /mnt/.snapshots/ 2>/dev/null | head -n5); do
                    local snap_path="/mnt/.snapshots/${snapshot}/snapshot"
                    [[ -d "${snap_path}" ]] || continue
                    cat >> "${esp_mount}/limine.conf" <<LIMINE_EOF

/Snapshot: ${snapshot} (${kver})
    protocol: linux
    kernel_path: boot():/${limine_kernel_name}
LIMINE_EOF
                    if [[ -n "${limine_microcode}" && -f "/mnt/boot/${limine_microcode}" ]]; then
                        cat >> "${esp_mount}/limine.conf" <<LIMINE_EOF
    module_path: boot():/${limine_microcode}
LIMINE_EOF
                    fi
                    if [[ -n "${limine_initramfs_name:-}" ]]; then
                        cat >> "${esp_mount}/limine.conf" <<LIMINE_EOF
    module_path: boot():/${limine_initramfs_name}
LIMINE_EOF
                    fi
                    cat >> "${esp_mount}/limine.conf" <<LIMINE_EOF
    cmdline: ${limine_root_cmdline} rootflags=subvol=.snapshots/${snapshot}/snapshot
    comment: Boot into snapshot ${snapshot} (${kver})
LIMINE_EOF
                done
            fi
        fi
    done

    if [[ ${found_kernel} -eq 0 ]]; then
        die "No kernel images found in /mnt/boot"
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
}