#!/usr/bin/env bash
set -Eeuo pipefail

readonly ROOT="/mnt"

recovery_detect_install() {
    mountpoint -q "${ROOT}" || return 1
    [[ -d "${ROOT}/etc" ]] || return 1
    return 0
}

recovery_import_state() {
    reconstruct_state_from_system
}

validate_recovery_root() {
    mountpoint -q "${ROOT}" \
        || die "recovery root is not mounted: ${ROOT}"

    [[ -d "${ROOT}/etc" ]] \
        || die "missing ${ROOT}/etc"

    [[ -d "${ROOT}/var/lib/pacman" ]] \
        || die "missing pacman database"
}

pacman_root_has() {
    [[ -d "${ROOT}/var/lib/pacman/local" ]] \
        || return 1

    pacman \
        --root "${ROOT}" \
        -Qq "${1}" \
        &>/dev/null
}

service_exists() {
    local path="${1}"
    [[ -e "${ROOT}/${path}" ]]
}

recovery_get_status() {
    local status=""
    status+="Install stage: $(state_get RECOVERY_STATUS unknown)"$'\n'
    status+="Filesystem: $(state_get FS_TYPE ext4)"$'\n'
    status+="LVM: $(state_get USE_LVM no)"$'\n'
    status+="LUKS: $(state_get USE_LUKS no)"$'\n'
    status+="UKI: $(state_get GENERATE_UKI no)"$'\n'
    status+="Bootloader: $(state_get BOOTLOADER unknown)"$'\n'
    status+="Kernel: $(state_get KERNEL_CHOICE unknown)"$'\n'
    status+="Power User: $(state_get POWER_USER no)"$'\n'
    status+="Coreutils: $(state_get COREUTILS unknown)"$'\n'
    local fstab_issues boot_issues pacman_issues
    fstab_issues=$(state_get FSTAB_ISSUES none)
    boot_issues=$(state_get BOOT_ISSUES none)
    pacman_issues=$(state_get PACMAN_ISSUES none)
    [[ "${fstab_issues}" != "none" ]] && status+=$'\n'"FSTAB issues: ${fstab_issues}"
    [[ "${boot_issues}" != "none" ]] && status+=$'\n'"Boot issues: ${boot_issues}"
    [[ "${pacman_issues}" != "none" ]] && status+=$'\n'"Pacman issues: ${pacman_issues}"
    printf '%s\n' "${status}"
}

reconstruct_state_from_system() {
    validate_recovery_root

    detect_disk
    detect_init
    detect_filesystem
    detect_zfs
    detect_lvm
    detect_bootloader
    detect_uki
    detect_kernel
    detect_desktop
    detect_display_manager
    detect_xstack
    detect_seat_manager
    detect_network_stack
    detect_audio_stack
    detect_ucode
    detect_user_shell
    detect_extras
    detect_repositories
    detect_username
    detect_luks
    detect_display_protocol
    detect_nvidia
    detect_virtualization
    detect_hostname
    detect_coreutils
    detect_poweruser
    detect_priv_escalation
    detect_install_stage
    detect_fstab_health
    detect_boot_health
    detect_pacman_health

    state_save
}