#!/usr/bin/env bash
set -Eeuo pipefail

readonly STATE_ROOT="/tmp/artix-installer"
readonly STATE_FILE="${STATE_ROOT}/state.conf"
readonly STAGE_DIR="${STATE_ROOT}/stages"
readonly LOG_DIR="${STATE_ROOT}/logs"

ensure_state_dirs() {
    mkdir -p "${STATE_ROOT}" "${STAGE_DIR}" "${LOG_DIR}"
}

state_save() {
    ensure_state_dirs
    {
        printf 'MODE=%q\n'                  "$(state_get MODE auto)"
        printf 'DISK=%q\n'                  "$(state_get DISK '')"
        printf 'FS_TYPE=%q\n'               "$(state_get FS_TYPE ext4)"
        printf 'INIT=%q\n'                  "$(state_get INIT openrc)"
        printf 'USE_LUKS=%q\n'              "$(state_get USE_LUKS no)"
        printf 'LUKS_PASS=%q\n'             "$(state_get LUKS_PASS '')"
        printf 'BOOTLOADER=%q\n'            "$(state_get BOOTLOADER grub)"
        printf 'DISPLAY_MANAGER=%q\n'       "$(state_get DISPLAY_MANAGER none)"
        printf 'AUDIO_STACK=%q\n'           "$(state_get AUDIO_STACK pipewire)"
        printf 'SWAP_ENABLED=%q\n'          "$(state_get SWAP_ENABLED no)"
        printf 'SWAP_SIZE=%q\n'             "$(state_get SWAP_SIZE 0)"
        printf 'EXTRAS=%q\n'                "$(state_get EXTRAS '')"
        printf 'KERNEL_CHOICE=%q\n'         "$(state_get KERNEL_CHOICE linux)"
        printf 'KERNEL_IMAGE=%q\n'          "$(state_get KERNEL_IMAGE '')"
        printf 'INITRAMFS_IMAGE=%q\n'       "$(state_get INITRAMFS_IMAGE '')"
        printf 'MICROCODE_IMAGE=%q\n'       "$(state_get MICROCODE_IMAGE '')"
        printf 'MICROCODE_OVERRIDE=%q\n'    "$(state_get MICROCODE_OVERRIDE auto)"
        printf 'HOSTNAME=%q\n'              "$(state_get HOSTNAME artix)"
        printf 'TIMEZONE=%q\n'              "$(state_get TIMEZONE Europe/Belgrade)"
        printf 'LOCALE=%q\n'                "$(state_get LOCALE en_US.UTF-8)"
        printf 'KEYMAP=%q\n'                "$(state_get KEYMAP us)"
        printf 'BTRFS_LAYOUT=%q\n'          "$(state_get BTRFS_LAYOUT standard)"
        printf 'WM_DE=%q\n'                 "$(state_get WM_DE none)"
        printf 'KDE_PROFILE=%q\n'           "$(state_get KDE_PROFILE desktop)"
        printf 'ROOT_PASS=%q\n'             "$(state_get ROOT_PASS '')"
        printf 'USER_COUNT=%q\n'            "$(state_get USER_COUNT 1)"
        local user_count
        user_count=$(state_get USER_COUNT 1)
        for ((i=1; i<=user_count; i++)); do
            printf "USER_%d_NAME=%q\n"   "$i" "$(state_get "USER_${i}_NAME" "")"
            printf "USER_%d_PASS=%q\n"   "$i" "$(state_get "USER_${i}_PASS" "")"
            printf "USER_%d_SHELL=%q\n"  "$i" "$(state_get "USER_${i}_SHELL" "/bin/bash")"
            printf "USER_%d_GROUPS=%q\n" "$i" "$(state_get "USER_${i}_GROUPS" "wheel,audio,video,storage")"
            printf "USER_%d_SUDO=%q\n"   "$i" "$(state_get "USER_${i}_SUDO" "yes")"
        done
        printf 'USER_SHELL=%q\n'            "$(state_get USER_SHELL /bin/bash)"
        printf 'PRIV_ESCALATION=%q\n'       "$(state_get PRIV_ESCALATION sudo)"
        printf 'NETWORK_STACK=%q\n'         "$(state_get NETWORK_STACK dhcpcd+iwd)"
        printf 'ALLOW_OFFLINE=%q\n'         "$(state_get ALLOW_OFFLINE no)"
        printf 'X_STACK=%q\n'               "$(state_get X_STACK xorg)"
        printf 'ENABLE_ARCH_REPOS=%q\n'     "$(state_get ENABLE_ARCH_REPOS no)"
        printf 'GENERATE_UKI=%q\n'          "$(state_get GENERATE_UKI no)"
        printf 'USE_LVM=%q\n'               "$(state_get USE_LVM no)"
        printf 'KEEP_BINARY_KERNEL=%q\n'    "$(state_get KEEP_BINARY_KERNEL yes)"
        printf 'COREUTILS=%q\n'             "$(state_get COREUTILS gnu)"
        printf 'KERNEL_CONFIG_DEPTH=%q\n'   "$(state_get KERNEL_CONFIG_DEPTH auto)"
        printf 'QUICK_INSTALL=%q\n'         "$(state_get QUICK_INSTALL no)"
        printf 'POWER_USER=%q\n'            "$(state_get POWER_USER no)"
        printf 'POWERUSER_PACKAGES=%q\n'    "$(state_get POWERUSER_PACKAGES '')"
        printf 'POWERUSER_PROFILE=%q\n'     "$(state_get POWERUSER_PROFILE default)"
        printf 'GUI_MODE=%q\n'              "$(state_get GUI_MODE no)"
        printf 'ENABLE_AURIS=%q\n'          "$(state_get ENABLE_AURIS no)"
        printf 'LUKS_KEYFILE=%q\n'          "$(state_get LUKS_KEYFILE no)"
        printf 'LUKS_KEYFILE_PATH=%q\n'     "$(state_get LUKS_KEYFILE_PATH '')"
        printf 'ISO_ARCH_REPOS=%q\n'        "$(state_get ISO_ARCH_REPOS no)"
        printf 'ARTIX_BOOT_MODE=%q\n'       "$(state_get ARTIX_BOOT_MODE uefi)"
        printf 'TKG_SCHEDULER=%q\n'         "$(state_get TKG_SCHEDULER eevdf)"
        printf 'TKG_BINARY=%q\n'            "$(state_get TKG_BINARY no)"
        printf 'TKG_COMPILER=%q\n'          "$(state_get TKG_COMPILER gcc)"
        printf 'TKG_OPTLEVEL=%q\n'          "$(state_get TKG_OPTLEVEL 1)"
        printf 'TKG_PROCESSOR_OPT=%q\n'     "$(state_get TKG_PROCESSOR_OPT native)"
        printf 'TKG_LTO_MODE=%q\n'          "$(state_get TKG_LTO_MODE no)"
        printf 'TKG_PREEMPT_RT=%q\n'        "$(state_get TKG_PREEMPT_RT 0)"
        printf 'TKG_TICKLESS=%q\n'          "$(state_get TKG_TICKLESS 2)"
        printf 'TKG_TIMER_FREQ=%q\n'        "$(state_get TKG_TIMER_FREQ 1000)"
        printf 'TKG_CPU_GOV=%q\n'           "$(state_get TKG_CPU_GOV ondemand)"
        printf 'TKG_GLITCHED_BASE=%q\n'     "$(state_get TKG_GLITCHED_BASE false)"
        printf 'TKG_ZENIFY=%q\n'            "$(state_get TKG_ZENIFY false)"
        printf 'TKG_CLEAR_PATCHES=%q\n'     "$(state_get TKG_CLEAR_PATCHES false)"
        printf 'TKG_OPENRGB=%q\n'           "$(state_get TKG_OPENRGB false)"
        printf 'TKG_ACS_OVERRIDE=%q\n'      "$(state_get TKG_ACS_OVERRIDE false)"
        printf 'TKG_FSYNC=%q\n'             "$(state_get TKG_FSYNC false)"
        printf 'TKG_MGLRU=%q\n'             "$(state_get TKG_MGLRU false)"
        printf 'TKG_NTSYNC=%q\n'            "$(state_get TKG_NTSYNC false)"
        printf 'TKG_NR_CPUS=%q\n'           "$(state_get TKG_NR_CPUS "$(nproc)")"
        printf 'KERNEL_ADV_FS=%q\n'         "$(state_get KERNEL_ADV_FS ext4)"
        printf 'KERNEL_ADV_GPU=%q\n'        "$(state_get KERNEL_ADV_GPU '')"
        printf 'KERNEL_ADV_NET=%q\n'        "$(state_get KERNEL_ADV_NET '')"
        printf 'KERNEL_ADV_SOUND=%q\n'      "$(state_get KERNEL_ADV_SOUND '')"
        printf 'KERNEL_ADV_USB=%q\n'        "$(state_get KERNEL_ADV_USB '')"
        printf 'KERNEL_ADV_SECURITY=%q\n'   "$(state_get KERNEL_ADV_SECURITY '')"
        printf 'KERNEL_ADV_VIRT=%q\n'       "$(state_get KERNEL_ADV_VIRT '')"
        printf 'KERNEL_ADV_DEBUG=%q\n'      "$(state_get KERNEL_ADV_DEBUG '')"
        printf 'KERNEL_PREEMPT=%q\n'        "$(state_get KERNEL_PREEMPT voluntary)"
        printf 'KERNEL_TIMER=%q\n'          "$(state_get KERNEL_TIMER 250)"
        printf 'KERNEL_GOVERNOR=%q\n'       "$(state_get KERNEL_GOVERNOR schedutil)"
    } > "${STATE_FILE}"
    chmod 600 "${STATE_FILE}"
}

state_load() {
    [[ -f "${STATE_FILE}" ]] || return 0
    source "${STATE_FILE}"
}

state_get() {
    local key="${1}"
    local default="${2:-}"
    printf '%s\n' "${!key:-${default}}"
}

state_set() {
    ensure_state_dirs
    local key="${1}" value="${2}"
    [[ -n "${key}" ]] || { log_error "state_set: empty key"; return 1; }
    export "${key}=${value}"

    if [[ -f "${STATE_FILE}" ]] && grep -q "^${key}=" "${STATE_FILE}" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}='${value}'|" "${STATE_FILE}"
    else
        printf "%s='%s'\n" "${key}" "${value}" >> "${STATE_FILE}"
    fi
}

stage_mark_done() {
    ensure_state_dirs;

    touch "${STAGE_DIR}/${1}.done";
}

stage_is_done() {
    [[ -f "${STAGE_DIR}/${1}.done" ]];
}

stage_reset() {
    rm -f "${STAGE_DIR}/${1}.done";
}

stage_reset_all() {
    rm -f "${STAGE_DIR}"/*.done;
}

stage_log_path() {
    ensure_state_dirs;

    printf '%s/%s.log\n' \
        "${LOG_DIR}" \
        "${1}";
}

stage_require_mount() {
    mountpoint -q /mnt
}

stage_require_storage() {
    stage_require_mount \
        && [[ -d /mnt/etc ]] \
        && (
            mountpoint -q /mnt/boot \
            || mountpoint -q /mnt/efi \
            || mountpoint -q /mnt/boot/efi \
            || [[ -f /mnt/etc/fstab ]]
        )
}

stage_require_chroot() {
    stage_require_storage \
        && [[ -x /mnt/usr/bin/bash ]] \
        && [[ -f /mnt/etc/fstab ]]
}

stage_require_post() {
    stage_require_chroot \
        && [[ -d /mnt/home || -d /mnt/root ]]
}

stage_validate() {
    local stage="${1}";

    case "${stage}" in
        preflight)  return 0 ;;
        storage)    [[ -b "$(state_get DISK)" ]] ;;
        base)       [[ -x /mnt/usr/bin/bash ]] && artix-chroot /mnt pacman -Q base &>/dev/null ;;
        poweruser)  [[ -f /mnt/etc/artix-poweruser/world.txt ]] && [[ -f /mnt/boot/vmlinuz-linux-custom ]] ;;
        chroot)     [[ -f /mnt/etc/fstab ]] && [[ -f /mnt/etc/hostname ]] ;;
        init)       return 0 ;;
        post)       [[ -d /mnt/home || -d /mnt/root ]] ;;
        finalize)   return 0 ;;
        *)          return 1 ;;
    esac
}

stage_reset_from() {
    local stage="${1}";
    local reset='false';
    local current;

    for current in \
        preflight \
        storage \
        base \
        poweruser \
        chroot \
        init \
        post \
        finalize; do

        if [[ "${current}" == "${stage}" ]]; then
            reset='true';
        fi

        if [[ "${reset}" == 'true' ]]; then
            stage_reset "${current}";
        fi
    done
}

stage_should_skip() {
    local stage="${1}";

    if ! stage_is_done "${stage}"; then
        return 1;
    fi

    if ! stage_validate "${stage}"; then
        printf '[!] Stage "%s" marked complete but environment is invalid.\n' \
            "${stage}";

        printf '[!] Resetting stage state...\n';

        stage_reset_from "${stage}";

        return 1;
    fi

    printf '[*] %s stage already completed. Skipping...\n' \
        "${stage^}";

    return 0;
}