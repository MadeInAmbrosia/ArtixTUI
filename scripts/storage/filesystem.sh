#!/usr/bin/env bash
set -Eeuo pipefail

create_filesystems() {
    local disk fs_type swap_enabled
    disk="$(state_get DISK)"
    [[ -b "${disk}" ]] || die "invalid disk: ${disk}"
    fs_type="$(state_get FS_TYPE)"
    swap_enabled="$(state_get SWAP_ENABLED no)"

    local efi_part swap_part root_part

    if [[ -n "$(state_get EFI_PART '')" ]]; then
        efi_part="$(state_get EFI_PART)"
        root_part="$(state_get ROOT_PART)"
        if [[ "$(state_get SWAP_ENABLED no)" == "yes" ]]; then
            swap_part="$(state_get SWAP_PART)"
        fi
    else
        efi_part=$(get_partition_name "${disk}" 1)
        if [[ "${swap_enabled}" == 'yes' ]]; then
            swap_part=$(get_partition_name "${disk}" 2)
            root_part=$(get_partition_name "${disk}" 3)
        else
            root_part=$(get_partition_name "${disk}" 2)
        fi
    fi

    [[ -b "${efi_part}" ]] || die "invalid EFI partition: ${efi_part}"
    [[ -b "${root_part}" ]] || die "invalid root partition: ${root_part}"
    [[ "/dev/$(lsblk -no PKNAME "${efi_part}" | tail -n1)" == "${disk}" ]] || die "EFI partition does not belong to selected disk"
    if [[ "$(state_get USE_LVM no)" != "yes" ]]; then
        [[ "/dev/$(lsblk -no PKNAME "${root_part}" | tail -n1)" == "${disk}" ]] || die "Root partition does not belong to selected disk"
    fi

    log_info "Wiping old filesystem signatures..."
    wipefs -af "${efi_part}" || true
    if [[ "$(state_get USE_LUKS no)" != "yes" ]]; then
        wipefs -af "${root_part}" || true
    fi

    if [[ "${swap_enabled}" == 'yes' ]]; then
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
        exfat)     pacman -S --needed --noconfirm exfatprogs ; modprobe exfat 2>/dev/null || true ;;
        zfs)
            command -v zpool >/dev/null || die 'zpool command unavailable'
            if ! modprobe zfs 2>/dev/null; then
                log_error "Failed to load ZFS kernel module. The live environment does not support ZFS."
                return 1
            fi ;;
    esac

    log_info "Formatting EFI partition..."
    mkfs.fat -F32 "${efi_part}" || recoverable_error 'Failed to create FAT32 EFI filesystem – update might fix this'
    partprobe "${disk}" || true
    udevadm settle || true

    if ! blkid -o value -s TYPE "${efi_part}" | grep -qi 'vfat'; then
        die "EFI partition ${efi_part} does not have a vfat signature — mkfs.fat may have failed silently"
    fi

    if [[ "${swap_enabled}" == 'yes' ]]; then
        log_info "Initializing swap..."
        [[ -b "${swap_part}" ]] || die "invalid swap partition: ${swap_part}"
        mkswap "${swap_part}"
        swapon "${swap_part}"
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
            exfat)    mkfs.exfat -L "root" "${root_lv}" ;;
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
        local luks_pass
        luks_pass="$(state_get LUKS_PASS)"
        printf '%s' "${luks_pass}" | cryptsetup luksFormat --type luks2 "${fs_target}" -
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
        exfat)
            log_info "Creating exFAT filesystem..."
            mkfs.exfat -L "root" "${fs_target}"
            ;;
        zfs)
            log_info "Clearing old ZFS labels..."
            zpool labelclear -f "${fs_target}" 2>/dev/null || true
            wipefs -af "${fs_target}" 2>/dev/null || true
            log_info "Creating ZFS pool..."
            zpool create -f \
                -o ashift=12 \
                -O compression=zstd \
                -O atime=off \
                -O mountpoint=none \
                zroot "${fs_target}"
            zfs create -o mountpoint=/ zroot/root
            zfs mount zroot/root
            mkdir -p /mnt/boot
            ;;
    esac

    log_info "Filesystem creation complete."
}