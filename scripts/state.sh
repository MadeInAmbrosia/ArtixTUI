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
        printf 'MODE=%q\n'                  "${MODE:-auto}"
        printf 'DISK=%q\n'                  "${DISK:-}"
        printf 'FS_TYPE=%q\n'               "${FS_TYPE:-}"
        printf 'INIT=%q\n'                  "${INIT:-}"
        printf 'USE_LUKS=%q\n'              "${USE_LUKS:-}"
        printf 'LUKS_PASS=%q\n'             "${LUKS_PASS:-}"
        printf 'BOOTLOADER=%q\n'            "${BOOTLOADER:-}"
        printf 'DISPLAY_MANAGER=%q\n'       "${DISPLAY_MANAGER:-none}"
        printf 'AUDIO_STACK=%q\n'           "${AUDIO_STACK:-pipewire}"
        printf 'SWAP_ENABLED=%q\n'          "${SWAP_ENABLED:-no}"
        printf 'SWAP_SIZE=%q\n'             "${SWAP_SIZE:-0}"
        printf 'EXTRAS=%q\n'                "${EXTRAS:-}"
        printf 'KERNEL_CHOICE=%q\n'         "${KERNEL_CHOICE:-}"
        printf 'KERNEL_IMAGE=%q\n'          "${KERNEL_IMAGE:-}"
        printf 'INITRAMFS_IMAGE=%q\n'       "${INITRAMFS_IMAGE:-}"
        printf 'MICROCODE_IMAGE=%q\n'       "${MICROCODE_IMAGE:-}"
        printf 'MICROCODE_OVERRIDE=%q\n'    "${MICROCODE_OVERRIDE:-auto}"
        printf 'HOSTNAME=%q\n'              "${HOSTNAME:-artix}"
        printf 'TIMEZONE=%q\n'              "${TIMEZONE:-Europe/Belgrade}"
        printf 'LOCALE=%q\n'                "${LOCALE:-en_US.UTF-8}"
        printf 'KEYMAP=%q\n'                "${KEYMAP:-us}"
        printf 'BTRFS_LAYOUT=%q\n'          "${BTRFS_LAYOUT:-standard}"
        printf 'WM_DE=%q\n'                 "${WM_DE:-}"
        printf 'KDE_PROFILE=%q\n'           "${KDE_PROFILE:-desktop}"
        printf 'ROOT_PASS=%q\n'             "${ROOT_PASS:-}"
        printf 'USER_COUNT=%q\n'            "${USER_COUNT:-1}"
        for ((i=1; i<=${USER_COUNT:-1}; i++)); do
            printf "USER_%d_NAME=%q\n"   "$i" "$(state_get "USER_${i}_NAME" "")"
            printf "USER_%d_PASS=%q\n"   "$i" "$(state_get "USER_${i}_PASS" "")"
            printf "USER_%d_SHELL=%q\n"  "$i" "$(state_get "USER_${i}_SHELL" "/bin/bash")"
            printf "USER_%d_GROUPS=%q\n" "$i" "$(state_get "USER_${i}_GROUPS" "wheel,audio,video,storage")"
            printf "USER_%d_SUDO=%q\n"   "$i" "$(state_get "USER_${i}_SUDO" "yes")"
        done
        printf 'USER_SHELL=%q\n'            "${USER_SHELL:-/bin/bash}"
        printf 'PRIV_ESCALATION=%q\n'       "${PRIV_ESCALATION:-sudo}"
        printf 'NETWORK_STACK=%q\n'         "${NETWORK_STACK:-dhcpcd+iwd}"
        printf 'ALLOW_OFFLINE=%q\n'         "${ALLOW_OFFLINE:-no}"
        printf 'X_STACK=%q\n'               "${X_STACK:-xorg}"
        printf 'ENABLE_ARCH_REPOS=%q\n'     "${ENABLE_ARCH_REPOS:-no}"
        printf 'GENERATE_UKI=%q\n'         "${GENERATE_UKI:-no}"
        printf 'USE_LVM=%q\n'              "${USE_LVM:-no}"
        printf 'KEEP_BINARY_KERNEL=%q\n'   "${KEEP_BINARY_KERNEL:-yes}"
        printf 'COREUTILS=%q\n'            "${COREUTILS:-gnu}"
        printf 'KERNEL_CONFIG_DEPTH=%q\n'  "${KERNEL_CONFIG_DEPTH:-auto}"
        printf 'QUICK_INSTALL=%q\n'        "${QUICK_INSTALL:-no}"
        printf 'POWER_USER=%q\n'            "${POWER_USER:-no}"
        printf 'POWERUSER_PACKAGES=%q\n'    "${POWERUSER_PACKAGES:-}"
        printf 'POWERUSER_PROFILE=%q\n'     "${POWERUSER_PROFILE:-default}"
        printf 'GUI_MODE=%q\n'               "${GUI_MODE:-no}"
        printf 'ENABLE_AURIS=%q\n'          "${ENABLE_AURIS:-no}"
        printf 'LUKS_KEYFILE=%q\n'         "${LUKS_KEYFILE:-no}"
        printf 'LUKS_KEYFILE_PATH=%q\n'    "${LUKS_KEYFILE_PATH:-}"
        printf 'ISO_ARCH_REPOS=%q\n'       "${ISO_ARCH_REPOS:-no}"
        printf 'ARTIX_BOOT_MODE=%q\n'      "${ARTIX_BOOT_MODE:-uefi}"
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
    local key="${1}"
    local value="${2}"
    export "${key}=${value}"
    local tmpfile="${STATE_FILE}.tmp.$$"
    if [[ -f "${STATE_FILE}" ]]; then
        while IFS= read -r line; do
            if [[ "${line}" =~ ^${key}= ]]; then
                printf '%s=%q\n' "${key}" "${value}" >> "${tmpfile}"
            else
                printf '%s\n' "${line}" >> "${tmpfile}"
            fi
        done < "${STATE_FILE}"
    else
        : > "${tmpfile}"
    fi
    if ! grep -qE "^${key}=" "${STATE_FILE}" 2>/dev/null; then
        printf '%s=%q\n' "${key}" "${value}" >> "${tmpfile}"
    fi
    mv "${tmpfile}" "${STATE_FILE}"
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