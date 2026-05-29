#!/usr/bin/env bash
set -Eeuo pipefail

tui_select_luks() {
    if tui_yesno "Disk Encryption" "Enable LUKS full disk encryption?"; then
        state_set USE_LUKS "yes"
        local pass
        pass=$(tui_password_confirm "LUKS Passphrase" "Enter passphrase:" "Confirm passphrase:") || return 1
        state_set LUKS_PASS "${pass}"
    else
        state_set USE_LUKS "no"
    fi

    if tui_yesno "LVM" "Enable Logical Volume Management (LVM)?"; then
        state_set USE_LVM "yes"
    else
        state_set USE_LVM "no"
    fi
}

tui_select_arch_repos() {
    local kernel fs_type wm_de required='no' reasons=()
    kernel="$(state_get KERNEL_CHOICE linux)"
    fs_type="$(state_get FS_TYPE ext4)"
    wm_de="$(state_get WM_DE none)"

    case "${kernel}" in
        linux-bazzite-bin|linux-cachyos-bore|xanmod) required='yes'; reasons+=("Kernel ${kernel}") ;;
    esac
    case "${fs_type}" in
        zfs) required='yes'; reasons+=("ZFS filesystem") ;;
    esac
    case "${wm_de}" in
        hyprland|niri) required='yes'; reasons+=("${wm_de} may need Arch packages") ;;
    esac

    if [[ "${required}" == "yes" ]]; then
        local reason_list
        reason_list=$(printf ' - %s\n' "${reasons[@]}")
        tui_msg_quick "Arch Repositories Required" $'Enabling official Arch repositories because:\n\n'"${reason_list}"
        state_set ENABLE_ARCH_REPOS "yes"
        return 0
    fi

    if tui_yesno "Arch Repositories" "Enable official Arch repositories?"; then
        state_set ENABLE_ARCH_REPOS "yes"
    else
        state_set ENABLE_ARCH_REPOS "no"
    fi
}

tui_select_offline_mode() {
    local off
    off=$(tui_menu "Offline Installation" "Allow offline installation?" "No (require internet)" "Yes (cached install)") || return 1
    case "${off}" in
        Yes*) state_set ALLOW_OFFLINE "yes" ;;
        *)     state_set ALLOW_OFFLINE "no" ;;
    esac
}

tui_select_btrfs_layout() {
    local fs_type
    fs_type="$(state_get FS_TYPE ext4)"
    [[ "${fs_type}" == "btrfs" ]] || return 0
    local layout
    layout=$(tui_menu "BTRFS Layout" "Select subvolume layout:" "standard" "flat" "snapshot") || return 1
    state_set BTRFS_LAYOUT "${layout}"
}