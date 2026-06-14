#!/usr/bin/env bash
set -Eeuo pipefail

bootloader_install_efistub() {
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
    local cmdline=""
    if [[ "${fs_type}" == 'zfs' ]]; then
        cmdline="root=ZFS=zroot/root rw modules=zfs rootfstype=zfs"
    else
        if [[ "$(state_get USE_LUKS no)" == "yes" ]]; then
            cmdline+="cryptdevice=UUID=${crypt_uuid}:${mapper_name} "
        fi
        if [[ "$(state_get USE_LVM no)" == "yes" ]]; then
            cmdline+="root=/dev/vg0/root "
        elif [[ "$(state_get USE_LUKS no)" == "yes" ]]; then
            cmdline+="root=/dev/mapper/${mapper_name} "
        else
            cmdline+="root=UUID=${root_uuid} "
        fi
        cmdline+="rw"
    fi
    [[ -n "${microcode_image_str:-}" ]] && cmdline+=" ${microcode_image_str}"
    cmdline+=" initrd=\\EFI\\Artix\\${initramfs_basename}"

    log_info "Creating EFI boot entry..."
    artix-chroot /mnt efibootmgr --create --disk "${esp_disk}" --part "${esp_part}" \
        --label 'Artix Linux' --loader "${loader}" --unicode "${cmdline}" --verbose \
        || die 'failed to create EFI boot entry'

    log_info "Verifying EFI boot entries..."
    artix-chroot /mnt efibootmgr -v | grep -qi 'Artix Linux' || die "failed to verify EFI boot entry"
}