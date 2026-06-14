#!/usr/bin/env bash
set -Eeuo pipefail

bootloader_install_grub() {
    log_info "Installing GRUB..."
    findmnt -rn -o FSTYPE /mnt/boot/efi | grep -qx 'vfat' || die 'EFI partition not mounted as vfat'

    if [[ "${fs_type}" == 'zfs' ]]; then
        log_info "Applying ZFS GRUB compatibility fixes..."
        if ! grep -q 'ZPOOL_VDEV_NAME_PATH' /mnt/etc/profile 2>/dev/null; then
            echo 'export ZPOOL_VDEV_NAME_PATH=YES' >> /mnt/etc/profile
        fi
        if [[ -f /mnt/etc/grub.d/10_linux ]]; then
            artix-chroot /mnt sed -i \
                "s|rpool=.*|rpool=\`zdb -l \${GRUB_DEVICE} \| grep -E '[[:blank:]]name' \| cut -d\\\' -f 2\`|" \
                /etc/grub.d/10_linux
        fi
    fi

    if [[ "$(state_get USE_LUKS no)" == "yes" ]]; then
        echo 'GRUB_ENABLE_CRYPTODISK=y' >> /mnt/etc/default/grub
        local grub_cmdline="cryptdevice=UUID=${crypt_uuid}:${mapper_name}"
        if [[ "$(state_get USE_LVM no)" == "yes" ]]; then
            grub_cmdline+=" root=/dev/vg0/root"
        else
            grub_cmdline+=" root=/dev/mapper/${mapper_name}"
        fi
        artix-chroot /mnt sed -i "s|^GRUB_CMDLINE_LINUX=\"\(.*\)\"|GRUB_CMDLINE_LINUX=\"\1 ${grub_cmdline}\"|" /etc/default/grub
    fi

    if [[ "${fs_type}" == "xfs" ]]; then
        log_info "Verifying XFS features for GRUB compatibility..."
        if artix-chroot /mnt xfs_info "${root_device}" 2>/dev/null | grep -q 'bigtime=1'; then
            die "XFS bigtime is enabled and may be incompatible with older GRUB builds."
        fi
    fi

    local grub_extra=""
    [[ "${fs_type}" == 'zfs' ]] && grub_extra="--removable"
    xtrace_safe artix-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ARTIX ${grub_extra} || recoverable_error 'grub-install failed – updating ArtixForge may help'
    if [[ -n "${root_param}" ]]; then
        artix-chroot /mnt sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"${root_param}\"|" /etc/default/grub
    fi
    log_info "Generating GRUB configuration..."
    xtrace_safe artix-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg || recoverable_error 'grub-mkconfig failed – updating ArtixForge may fix this'
}