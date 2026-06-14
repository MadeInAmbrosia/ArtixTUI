#!/usr/bin/env bash
set -Eeuo pipefail

bootloader_install_refind() {
    log_info "Installing rEFInd..."
    findmnt -rn -o FSTYPE /mnt/boot/efi | grep -qx 'vfat' || die 'EFI partition not mounted as vfat'
    local refind_root_param
    if [[ -n "${root_param}" ]]; then
        refind_root_param="${root_param}"
    else
        refind_root_param=""
        if [[ "$(state_get USE_LUKS no)" == "yes" ]]; then
            refind_root_param+="cryptdevice=UUID=${crypt_uuid}:${mapper_name} "
        fi
        if [[ "$(state_get USE_LVM no)" == "yes" ]]; then
            refind_root_param+="root=/dev/vg0/root"
        elif [[ "$(state_get USE_LUKS no)" == "yes" ]]; then
            refind_root_param+="root=/dev/mapper/${mapper_name}"
        else
            local refind_root_device refind_root_uuid
            refind_root_device=$(findmnt -n -o SOURCE --target /mnt)
            refind_root_device="${refind_root_device%%[*]}"
            refind_root_uuid=$(blkid -s UUID -o value "${refind_root_device}")
            refind_root_param+="root=UUID=${refind_root_uuid}"
        fi
    fi
    artix-chroot /mnt bash -c "echo \"${refind_root_param} rw\" > /boot/refind_linux.conf"
    artix-chroot /mnt refind-install || die 'refind-install failed'
}