#!/usr/bin/env bash
set -Eeuo pipefail

stage_storage() {
    if stage_should_skip storage; then return 0; fi

    if [[ "$(state_get INSTALL_MODE auto)" == "manual" ]]; then
        tui_select_disk

        local disk
        disk="$(state_get DISK)"
        [[ -n "${disk}" ]] || die "No disk selected"

        tui_msg_quick "Manual Partitioning" \
            "Partition ${disk} now using your preferred tool (cfdisk, fdisk, etc.).\n\nPress OK when done."

        partprobe "${disk}" 2>/dev/null || true
        udevadm settle
        sleep 1

        lsblk "${disk}"

        local efi_part root_part swap_part
        efi_part=$(tui_input "EFI Partition" "Enter EFI partition (e.g. ${disk}1):" "${disk}1") || die "EFI partition required"
        root_part=$(tui_input "Root Partition" "Enter root partition (e.g. ${disk}2):" "${disk}2") || die "Root partition required"

        [[ -b "${efi_part}" ]] || die "EFI partition ${efi_part} does not exist"
        [[ -b "${root_part}" ]] || die "Root partition ${root_part} does not exist"

        state_set EFI_PART "${efi_part}"
        state_set ROOT_PART "${root_part}"

        if tui_yesno "Swap Partition" "Did you create a swap partition?"; then
            swap_part=$(tui_input "Swap Partition" "Enter swap partition (leave empty to skip):" "") || true
            if [[ -n "${swap_part}" && -b "${swap_part}" ]]; then
                state_set SWAP_PART "${swap_part}"
                state_set SWAP_ENABLED "yes"
            fi
        fi
    else
        partition_disk
    fi

    create_filesystems
    mount_filesystems
    stage_mark_done storage
}