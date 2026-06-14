#!/usr/bin/env bash
set -Eeuo pipefail

basestrap_zfs_setup() {
    local INST_UUID
    INST_UUID="$(state_get ZFS_UUID)"
    [[ -n "${INST_UUID}" ]] || die "ZFS UUID not found in state"

    log_info "Generating hostid for ZFS..."
    artix-chroot /mnt zgenhostid

    log_info "Adding ZFS hook to mkinitcpio..."
    artix-chroot /mnt sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block keyboard zfs filesystems)/' /etc/mkinitcpio.conf

    log_info "Generating ZFS fstab entries..."
    cat > /mnt/etc/fstab <<EOF
bpool_${INST_UUID}/BOOT/default /boot zfs rw,xattr,posixacl 0 0
EOF
    local efi_part
    efi_part=$(get_partition_name "$(state_get DISK)" 1)
    echo "UUID=$(blkid -s UUID -o value "${efi_part}") /boot/efi vfat umask=0022,fmask=0022,dmask=0022 0 1" >> /mnt/etc/fstab

    log_info "Adding archzfs repository to target..."
    if ! grep -q '^\[archzfs\]' /mnt/etc/pacman.conf 2>/dev/null; then
        cat >> /mnt/etc/pacman.conf <<'EOF'
[archzfs]
Server = https://archzfs.com/$repo/$arch
Server = https://mirror.sum7.eu/archlinux/archzfs/$repo/$arch
Server = https://mirror.biocrafting.net/archlinux/archzfs/$repo/$arch
Server = https://mirror.in.themindsmaze.com/archzfs/$repo/$arch
EOF
    fi

    log_info "Creating zfs-mount init script..."
    cat > /mnt/etc/init.d/zfs-mount <<'ZFSMOUNT'
#!/usr/bin/openrc-run

start() {
    /usr/bin/zfs mount -a
}
ZFSMOUNT
    chmod +x /mnt/etc/init.d/zfs-mount
    enable_service_boot zfs-mount

    log_info "Generating ZFS pool cache..."
    artix-chroot /mnt zpool set cachefile=/etc/zfs/zpool.cache "bpool_${INST_UUID}"
    artix-chroot /mnt zpool set cachefile=/etc/zfs/zpool.cache "rpool_${INST_UUID}"

    echo 'export ZPOOL_VDEV_NAME_PATH=YES' >> /mnt/etc/profile
}