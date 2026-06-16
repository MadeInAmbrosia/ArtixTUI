#!/usr/bin/env bash
set -Eeuo pipefail

create_filesystems() {
    local disk fs_type swap_enabled
    disk="$(state_get DISK)"
    [[ -b "${disk}" ]] || die "invalid disk: ${disk}"
    fs_type="$(state_get FS_TYPE)"
    swap_enabled="$(state_get SWAP_ENABLED no)"

    local efi_part swap_part root_part boot_pool_part

    if [[ -n "$(state_get EFI_PART '')" ]]; then
        efi_part="$(state_get EFI_PART)"
        root_part="$(state_get ROOT_PART)"
        if [[ "$(state_get SWAP_ENABLED no)" == "yes" ]]; then
            swap_part="$(state_get SWAP_PART)"
        fi
    else
        efi_part=$(get_partition_name "${disk}" 1)
        if [[ "${fs_type}" == "zfs" ]]; then
            boot_pool_part=$(get_partition_name "${disk}" 2)
            root_part=$(get_partition_name "${disk}" 3)
            if [[ "${swap_enabled}" == 'yes' ]]; then
                swap_part=$(get_partition_name "${disk}" 4)
            fi
        else
            if [[ "${swap_enabled}" == 'yes' ]]; then
                swap_part=$(get_partition_name "${disk}" 2)
                root_part=$(get_partition_name "${disk}" 3)
            else
                root_part=$(get_partition_name "${disk}" 2)
            fi
        fi
    fi

    [[ -b "${efi_part}" ]] || die "invalid EFI partition: ${efi_part}"
    [[ -b "${root_part}" ]] || die "invalid root partition: ${root_part}"
    [[ "/dev/$(lsblk -no PKNAME "${efi_part}" | tail -n1)" == "${disk}" ]] || die "EFI partition does not belong to selected disk"
    if [[ "$(state_get USE_LVM no)" != "yes" && "${fs_type}" != "zfs" ]]; then
        [[ "/dev/$(lsblk -no PKNAME "${root_part}" | tail -n1)" == "${disk}" ]] || die "Root partition does not belong to selected disk"
    fi

    log_info "Wiping old filesystem signatures..."
    wipefs -af "${efi_part}" || true
    if [[ "${fs_type}" != "zfs" && "$(state_get USE_LUKS no)" != "yes" ]]; then
        wipefs -af "${root_part}" || true
    fi
    if [[ "${swap_enabled}" == 'yes' && -n "${swap_part:-}" ]]; then
        wipefs -af "${swap_part}" || true
    fi

    log_info "Ensuring EFI filesystem support..."
    pacman -S --needed --noconfirm dosfstools
    modprobe fat 2>/dev/null || true
    modprobe vfat 2>/dev/null || true

    case "${fs_type}" in
        btrfs)     pacman -S --needed --noconfirm btrfs-progs ; modprobe btrfs 2>/dev/null || true ;;
        ext4)      pacman -S --needed --noconfirm e2fsprogs  ; modprobe ext4 2>/dev/null || true ;;
        xfs)       pacman -S --needed --noconfirm xfsprogs   ; modprobe xfs 2>/dev/null || true ;;
        f2fs)      pacman -S --needed --noconfirm f2fs-tools ; command -v mkfs.f2fs >/dev/null || die 'mkfs.f2fs unavailable'; modprobe f2fs 2>/dev/null || true ;;
        bcachefs)
            if ! command -v mkfs.bcachefs >/dev/null 2>&1; then
                pacman -S --needed --noconfirm bcachefs-tools 2>/dev/null || true
            fi
            command -v mkfs.bcachefs >/dev/null || die 'mkfs.bcachefs unavailable'
            modprobe bcachefs 2>/dev/null || true ;;
        zfs)
            command -v zpool >/dev/null || die 'zpool command unavailable'
            if ! modprobe zfs 2>/dev/null; then
                log_error "Failed to load ZFS kernel module. The live environment does not support ZFS."
                return 1
            fi
            ;;
    esac

    log_info "Formatting EFI partition..."
    mkfs.fat -F32 "${efi_part}" || recoverable_error 'Failed to create FAT32 EFI filesystem'
    partprobe "${disk}" || true
    udevadm settle || true

    if ! blkid -o value -s TYPE "${efi_part}" | grep -qi 'vfat'; then
        die "EFI partition ${efi_part} does not have a vfat signature — mkfs.fat may have failed silently"
    fi

    if [[ "${swap_enabled}" == 'yes' && -n "${swap_part:-}" ]]; then
        log_info "Initializing swap..."
        [[ -b "${swap_part}" ]] || die "invalid swap partition: ${swap_part}"
        mkswap "${swap_part}"
        swapon "${swap_part}"
    fi

    if [[ "${fs_type}" == "zfs" ]]; then
        local INST_UUID
        INST_UUID=$(dd if=/dev/urandom of=/dev/stdout bs=1 count=100 2>/dev/null | tr -dc 'a-z0-9' | cut -c-6)
        state_set ZFS_UUID "${INST_UUID}"

        local zfs_encrypt="no"
        local zfs_passphrase=""
        if tui_yesno "ZFS Encryption" "Enable ZFS native encryption on the root pool?"; then
            zfs_encrypt="yes"
            zfs_passphrase=$(tui_password_confirm "ZFS Passphrase" "Enter passphrase:" "Confirm passphrase:") || die "ZFS encryption cancelled"
            state_set ZFS_PASSPHRASE "${zfs_passphrase}"
        fi

        log_info "Creating ZFS boot pool (bpool_${INST_UUID})..."
        zpool create \
            -o ashift=12 \
            -d \
            -o feature@async_destroy=enabled \
            -o feature@bookmarks=enabled \
            -o feature@embedded_data=enabled \
            -o feature@empty_bpobj=enabled \
            -o feature@enabled_txg=enabled \
            -o feature@extensible_dataset=enabled \
            -o feature@filesystem_limits=enabled \
            -o feature@hole_birth=enabled \
            -o feature@large_blocks=enabled \
            -o feature@lz4_compress=enabled \
            -o feature@spacemap_histogram=enabled \
            -O acltype=posixacl \
            -O canmount=off \
            -O compression=lz4 \
            -O devices=off \
            -O normalization=formD \
            -O relatime=on \
            -O xattr=sa \
            -O mountpoint=/boot \
            -R /mnt \
            "bpool_${INST_UUID}" \
            "${boot_pool_part}" || die "Failed to create boot pool"

        log_info "Creating ZFS root pool (rpool_${INST_UUID})..."
        local rpool_create_args=(
            -o ashift=12
            -O acltype=posixacl
            -O canmount=off
            -O compression=zstd
            -O dnodesize=auto
            -O normalization=formD
            -O relatime=on
            -O xattr=sa
            -O mountpoint=/
            -R /mnt
        )

        if [[ "${zfs_encrypt}" == "yes" ]]; then
            rpool_create_args+=(
                -O encryption=aes-256-gcm
                -O keylocation=prompt
                -O keyformat=passphrase
            )
        fi

        rpool_create_args+=("rpool_${INST_UUID}" "${root_part}")

        if [[ "${zfs_encrypt}" == "yes" ]]; then
            printf '%s\n' "${zfs_passphrase}" | zpool create "${rpool_create_args[@]}" || die "Failed to create root pool"
        else
            zpool create "${rpool_create_args[@]}" || die "Failed to create root pool"
        fi

        zfs create -o canmount=off -o mountpoint=none "bpool_${INST_UUID}/BOOT"
        zfs create -o canmount=off -o mountpoint=none "rpool_${INST_UUID}/ROOT"
        zfs create -o canmount=off -o mountpoint=none "rpool_${INST_UUID}/DATA"

        zfs create -o mountpoint=legacy -o canmount=noauto "bpool_${INST_UUID}/BOOT/default"
        zfs create -o mountpoint=/ -o canmount=noauto "rpool_${INST_UUID}/ROOT/default"

        zfs mount "rpool_${INST_UUID}/ROOT/default"
        mkdir -p /mnt/boot
        mount -t zfs "bpool_${INST_UUID}/BOOT/default" /mnt/boot

        zfs create -o mountpoint=/ -o canmount=off "rpool_${INST_UUID}/DATA/default"

        for i in usr var var/lib; do
            zfs create -o canmount=off "rpool_${INST_UUID}/DATA/default/$i"
        done

        for i in home root srv usr/local var/log var/spool var/tmp; do
            zfs create -o canmount=on "rpool_${INST_UUID}/DATA/default/$i"
        done

        chmod 750 /mnt/root
        chmod 1777 /mnt/var/tmp

        log_info "ZFS filesystem creation complete."
        return 0
    fi

    local fs_target="${root_part}"

    if [[ "$(state_get USE_LVM no)" == "yes" ]]; then
        local root_lv="/dev/vg0/root"
        local home_lv="/dev/vg0/home"
        local data_lv="/dev/vg0/data"

        [[ -b "${root_lv}" ]] || die "Root LV not found: ${root_lv} — LVM may not have been set up correctly"

        log_info "LVM detected — creating filesystem on logical volume ${root_lv}..."

        case "${fs_type}" in
            btrfs)     mkfs.btrfs -f "${root_lv}" ;;
            ext4)      mkfs.ext4 -F "${root_lv}" ;;
            xfs)
                local xfs_config="/usr/share/xfsprogs/mkfs/lts_6.6.conf"
                if [[ -f "${xfs_config}" ]]; then
                    mkfs.xfs -f -c "options=${xfs_config}" -m bigtime=0 "${root_lv}"
                else
                    mkfs.xfs -f -m bigtime=0 "${root_lv}"
                    log_warn "XFS LTS config not found — using upstream defaults."
                fi
                ;;
            f2fs)
                local dev_rota
                dev_rota=$(lsblk -dno ROTA "${root_part}" 2>/dev/null)
                if [[ "${dev_rota}" == "0" ]]; then
                    log_warn "F2FS on non-rotational SSD — ext4 or XFS often perform better."
                    if ! tui_yesno "F2FS on SSD" "F2FS is designed for raw flash (eMMC/SD/USB). Continue?"; then
                        die "User aborted F2FS creation"
                    fi
                fi
                mkfs.f2fs -f -O extra_attr,compression "${root_lv}"
                ;;
            bcachefs) mkfs.bcachefs --force --replicas=1 "${root_lv}" ;;
            zfs)      die "ZFS on LVM is not supported — use ZFS directly on the partition" ;;
            *)        die "Unsupported filesystem for LVM: ${fs_type}" ;;
        esac

        if [[ -b "${home_lv}" ]]; then
            log_info "Creating filesystem on home LV..."
            mkfs.ext4 -F "${home_lv}"
        fi
        if [[ -b "${data_lv}" ]]; then
            log_info "Creating filesystem on data LV..."
            mkfs.ext4 -F "${data_lv}"
        fi

        log_info "LVM filesystem creation complete."
        return 0
    fi

    if [[ "$(state_get USE_LUKS no)" == "yes" ]]; then
        log_info "Setting up LUKS on ${fs_target}..."
        cryptsetup close cryptroot 2>/dev/null || true
        local luks_pass
        luks_pass="$(state_get LUKS_PASS)"
        printf '%s' "${luks_pass}" | cryptsetup luksFormat --type luks2 --pbkdf pbkdf2 "${fs_target}" -
        printf '%s' "${luks_pass}" | cryptsetup luksOpen "${fs_target}" cryptroot -
        fs_target="/dev/mapper/cryptroot"
    fi

    case "${fs_type}" in
        btrfs)
            log_info "Creating BTRFS filesystem..."
            mkfs.btrfs -f "${fs_target}"
            ;;
        ext4)
            log_info "Creating EXT4 filesystem..."
            mkfs.ext4 -F "${fs_target}"
            ;;
        xfs)
            log_info "Creating XFS filesystem (GRUB-compatible)..."
            local xfs_config="/usr/share/xfsprogs/mkfs/lts_6.6.conf"
            if [[ -f "${xfs_config}" ]]; then
                mkfs.xfs -f -c "options=${xfs_config}" -m bigtime=0 "${fs_target}"
            else
                mkfs.xfs -f -m bigtime=0 "${fs_target}"
                log_warn "XFS LTS config not found – using upstream defaults. GRUB may fail if features are incompatible."
            fi
            ;;
        f2fs)
            log_info "Creating F2FS filesystem..."
            local dev_rota
            dev_rota=$(lsblk -dno ROTA "${fs_target}" 2>/dev/null)
            if [[ "${dev_rota}" == "0" ]]; then
                log_warn "F2FS on non-rotational SSD – ext4 or XFS often perform better."
                if ! tui_yesno "F2FS on SSD" "F2FS is designed for raw flash (eMMC/SD/USB). Continue?"; then
                    die "User aborted F2FS creation"
                fi
            fi
            mkfs.f2fs -f -O extra_attr,compression "${fs_target}"
            ;;
        bcachefs)
            log_info "Creating Bcachefs filesystem..."
            mkfs.bcachefs --force --replicas=1 "${fs_target}"
            ;;
        *)
            die "Unsupported filesystem: ${fs_type}"
            ;;
    esac

    log_info "Filesystem creation complete."
}