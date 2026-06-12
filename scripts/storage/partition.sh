#!/usr/bin/env bash
set -Eeuo pipefail

partition_disk() {
    local disk swap_enabled='no' swap_size='0'
    disk="$(state_get DISK)"
    [[ -n "${disk}" ]] || die 'no disk selected'
    [[ -b "${disk}" ]] || die 'invalid disk device'

    if tui_yesno "Swap Partition" "Would you like to create a swap partition?"; then
        swap_enabled='yes'
        local mem_gib=$(awk '/MemTotal/ {printf "%d", ($2 / 1024 / 1024) + 1}' /proc/meminfo)
        if [[ "${mem_gib}" -le 8 ]]; then swap_size='4G'
        elif [[ "${mem_gib}" -le 16 ]]; then swap_size='8G'
        else swap_size='16G'; fi
        swap_size=$(tui_input "Swap Size" $'Recommended swap size: '"${swap_size}"$'\n\nEnter desired swap size:' "${swap_size}")
        [[ -n "${swap_size}" ]] || die 'invalid swap size'
    fi
    state_set SWAP_ENABLED "${swap_enabled}"
    state_set SWAP_SIZE "${swap_size}"

    log_info "Preparing disk ${disk}..."
    swapoff -a 2>/dev/null || true
    umount -R /mnt 2>/dev/null || true
    zpool export -a 2>/dev/null || true
    vgchange -an vg0 2>/dev/null || true
    dmsetup remove_all 2>/dev/null || true

    log_info "Wiping existing signatures..."
    wipefs --all --force "${disk}"
    sgdisk --zap-all "${disk}"
    dd if=/dev/zero of="${disk}" bs=1M count=32 conv=fsync status=none
    blockdev --rereadpt "${disk}" 2>/dev/null || true

    local fs_type
    fs_type="$(state_get FS_TYPE ext4)"

    if [[ "${fs_type}" == "zfs" ]]; then
        log_info "Creating ZFS GPT partition layout..."
        # EFI System (1GB)
        sgdisk -n1:0:+1G -t1:EF00 "${disk}"
        # Boot pool (4GB)
        sgdisk -n2:0:+4G -t2:BE00 "${disk}"
        if [[ "${swap_enabled}" == 'yes' ]]; then
            sgdisk -n3:0:-"${swap_size}" -t3:BF00 "${disk}"
            sgdisk -n4:0:0 -t4:8200 "${disk}"
        else
            sgdisk -n3:0:0 -t3:BF00 "${disk}"
        fi
    else
        log_info "Creating GPT partition layout..."
        sgdisk -n1:0:+1024M -t1:ef00 "${disk}"
        if [[ "${swap_enabled}" == 'yes' ]]; then
            sgdisk -n2:0:+"${swap_size}" -t2:8200 "${disk}"
            sgdisk -n3:0:0 -t3:8300 "${disk}"
        else
            sgdisk -n2:0:0 -t2:8300 "${disk}"
        fi
    fi

    partprobe "${disk}" 2>/dev/null || true
    udevadm settle
    sleep 2
    blockdev --rereadpt "${disk}" 2>/dev/null || true

    [[ -b "$(get_partition_name "${disk}" 1)" ]] || die 'EFI partition not created'
    if [[ "${fs_type}" == "zfs" ]]; then
        [[ -b "$(get_partition_name "${disk}" 2)" ]] || die 'boot pool partition not created'
        [[ -b "$(get_partition_name "${disk}" 3)" ]] || die 'root pool partition not created'
        if [[ "${swap_enabled}" == 'yes' ]]; then
            [[ -b "$(get_partition_name "${disk}" 4)" ]] || die 'swap partition not created'
        fi
    else
        if [[ "${swap_enabled}" == 'yes' ]]; then
            [[ -b "$(get_partition_name "${disk}" 2)" ]] || die 'swap partition not created'
            [[ -b "$(get_partition_name "${disk}" 3)" ]] || die 'root partition not created'
        else
            [[ -b "$(get_partition_name "${disk}" 2)" ]] || die 'root partition not created'
        fi
    fi

    if [[ "$(state_get USE_LVM no)" == "yes" && "${fs_type}" != "zfs" ]]; then
        log_info "Setting up LVM..."
        local root_part
        if [[ "${swap_enabled}" == 'yes' ]]; then
            root_part=$(get_partition_name "${disk}" 3)
        else
            root_part=$(get_partition_name "${disk}" 2)
        fi

        sgdisk -t "$(lsblk -no PARTN "${root_part}" | head -n1)":8e00 "${disk}"
        partprobe "${disk}" 2>/dev/null || true
        udevadm settle

        local lvm_target="${root_part}"

        if [[ "$(state_get USE_LUKS no)" == "yes" ]]; then
            dmsetup remove cryptlvm 2>/dev/null || true
            wipefs -af "${root_part}" || true
            log_info "Formatting LUKS container on ${root_part}..."
            local luks_pass
            luks_pass="$(state_get LUKS_PASS)"
            printf '%s' "${luks_pass}" | cryptsetup luksFormat --type luks2 --pbkdf pbkdf2 "${root_part}" -
            log_info "Opening LUKS container..."
            printf '%s' "${luks_pass}" | cryptsetup luksOpen "${root_part}" cryptlvm -
            if [[ ! -b /dev/mapper/cryptlvm ]]; then
                die "LUKS mapper /dev/mapper/cryptlvm not created — check passphrase and kernel modules"
            fi
            lvm_target="/dev/mapper/cryptlvm"
        fi

        xtrace_safe pvcreate -ff "${lvm_target}" || die "pvcreate failed"
        xtrace_safe vgcreate vg0 "${lvm_target}" || die "vgcreate failed"
        xtrace_safe lvcreate -L 20G -n root vg0 || die "lvcreate root failed"
        xtrace_safe lvcreate -L 8G -n home vg0 || true
        xtrace_safe lvcreate -l 100%FREE -n data vg0 || true
    fi

    log_info "Partitioning complete."
}