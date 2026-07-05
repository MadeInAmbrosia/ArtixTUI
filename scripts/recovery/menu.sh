#!/usr/bin/env bash
set -Eeuo pipefail

tui_recovery_hub() {
    local status_json
    status_json=$(cat <<JSONEOF
[
  {"label":"System","items":[
    {"key":"install_stage","label":"Install stage","value":"$(state_get RECOVERY_STATUS unknown)","status":"$([[ "$(state_get RECOVERY_STATUS unknown)" != "unknown" ]] && echo "ok" || echo "warn")"},
    {"key":"disk","label":"Disk","value":"$(state_get DISK unknown)","status":"$([[ -n "$(state_get DISK '')" ]] && echo "ok" || echo "warn")"},
    {"key":"init","label":"Init","value":"$(state_get INIT openrc)","status":"ok"},
    {"key":"fs_type","label":"Filesystem","value":"$(state_get FS_TYPE ext4)","status":"ok"},
    {"key":"luks","label":"LUKS","value":"$(state_get USE_LUKS no)","status":"ok"},
    {"key":"lvm","label":"LVM","value":"$(state_get USE_LVM no)","status":"ok"},
    {"key":"coreutils","label":"Coreutils","value":"$(state_get COREUTILS gnu)","status":"ok"},
    {"key":"priv_esc","label":"Privilege","value":"$(state_get PRIV_ESCALATION sudo)","status":"ok"}
  ]},
  {"label":"Boot","items":[
    {"key":"boot_mode","label":"Boot mode","value":"$(state_get ARTIX_BOOT_MODE uefi)","status":"ok"},
    {"key":"bootloader","label":"Bootloader","value":"$(state_get BOOTLOADER unknown)","status":"$([[ "$(state_get BOOTLOADER unknown)" != "unknown" ]] && echo "ok" || echo "warn")"},
    {"key":"kernel","label":"Kernel","value":"$(state_get KERNEL_CHOICE unknown)","status":"$([[ "$(state_get KERNEL_CHOICE unknown)" != "unknown" ]] && echo "ok" || echo "warn")"},
    {"key":"uki","label":"UKI","value":"$(state_get GENERATE_UKI no)","status":"ok"},
    {"key":"fstab","label":"fstab","value":"$(state_get FSTAB_ISSUES none)","status":"$([[ "$(state_get FSTAB_ISSUES none)" != "none" ]] && echo "error" || echo "ok")"},
    {"key":"boot_health","label":"Boot health","value":"$(state_get BOOT_ISSUES none)","status":"$([[ "$(state_get BOOT_ISSUES none)" != "none" ]] && echo "error" || echo "ok")"}
  ]},
  {"label":"Packages","items":[
    {"key":"pacman","label":"Pacman DB","value":"$(state_get PACMAN_ISSUES none)","status":"$([[ "$(state_get PACMAN_ISSUES none)" != "none" ]] && echo "error" || echo "ok")"},
    {"key":"power_user","label":"Power User","value":"$(state_get POWER_USER no)","status":"ok"},
    {"key":"repos","label":"Arch Repos","value":"$(state_get ENABLE_ARCH_REPOS no)","status":"ok"}
  ]},
  {"label":"Desktop","items":[
    {"key":"wm_de","label":"Desktop","value":"$(state_get WM_DE none)","status":"ok"},
    {"key":"display_manager","label":"Display Manager","value":"$(state_get DISPLAY_MANAGER none)","status":"ok"},
    {"key":"x_stack","label":"X Stack","value":"$(state_get X_STACK none)","status":"ok"},
    {"key":"seat_mgr","label":"Seat Manager","value":"$(state_get SEAT_MANAGER elogind)","status":"$([[ "$(state_get SEAT_MANAGER_DISABLED no)" == "yes" ]] && echo "error" || echo "ok")"},
    {"key":"network","label":"Network","value":"$(state_get NETWORK_STACK none)","status":"ok"},
    {"key":"audio","label":"Audio","value":"$(state_get AUDIO_STACK none)","status":"ok"},
    {"key":"hostname","label":"Hostname","value":"$(state_get HOSTNAME unknown)","status":"ok"},
    {"key":"username","label":"Username","value":"$(state_get USER_NAME unknown)","status":"ok"},
    {"key":"shell","label":"User shell","value":"$(state_get USER_SHELL bash)","status":"ok"},
    {"key":"ucode","label":"Microcode","value":"$(state_get CPU_UCODE none)","status":"ok"},
    {"key":"gpu","label":"GPU Driver","value":"$(state_get GPU_DRIVER none)","status":"$([[ "$(state_get GPU_DRIVER none)" != "none" ]] && echo "ok" || echo "warn")"},
    {"key":"vm","label":"VM Guest","value":"$(state_get VM_GUEST none)","status":"ok"}
  ]},
  {"label":"Extras","items":[
    {"key":"extras","label":"Extras","value":"$(state_get EXTRAS '')","status":"ok"}
  ]}
]
JSONEOF
)

    local repairs_json='[
        {"key":"repair_fstab","label":"Repair fstab"},
        {"key":"repair_pacman","label":"Repair pacman"},
        {"key":"repair_boot","label":"Repair boot"},
        {"key":"repair_kernel","label":"Repair kernel"},
        {"key":"repair_seat_manager","label":"Repair seat manager"},
        {"key":"repair_filesystem","label":"Repair filesystem"},
        {"key":"full_repair","label":"Fix everything"},
        {"key":"untrusted_recovery","label":"Untrusted recovery"}
    ]'

    local result
    result=$(tui_recovery "Recovery Mode" "${status_json}" "${repairs_json}")

    case "${result}" in
        "repair_fstab")          repair_fstab ;;
        "repair_pacman")         repair_pacman ;;
        "repair_boot")           repair_boot ;;
        "repair_kernel")         repair_kernel ;;
        "repair_seat_manager")   repair_seat_manager ;;
        "repair_filesystem")     repair_filesystem ;;
        "full_repair")           repair_system ;;
        "untrusted_recovery")    untrusted_recovery ;;
        *)                       return 1 ;;
    esac
    return 0
}