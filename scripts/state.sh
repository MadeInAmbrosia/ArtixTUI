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
    local tmp_state="${STATE_FILE}.tmp"
    local user_json user_count
    user_json=$(state_get USER_COUNT '')
    user_count=0
    if [[ -n "${user_json}" && "${user_json}" != "0" && "${user_json}" != "[]" ]]; then
        user_count=$(echo "${user_json}" | jq '. | length' 2>/dev/null || echo 0)
    fi
    {
        printf "MODE='%s'\n"                  "$(state_get MODE auto)"
        printf "DISK='%s'\n"                  "$(state_get DISK '')"
        printf "FS_TYPE='%s'\n"               "$(state_get FS_TYPE ext4)"
        printf "INIT='%s'\n"                  "$(state_get INIT openrc)"
        printf "USE_LUKS='%s'\n"              "$(state_get USE_LUKS no)"
        printf "LUKS_PASS='%s'\n"             "$(state_get LUKS_PASS '')"
        printf "BOOTLOADER='%s'\n"            "$(state_get BOOTLOADER grub)"
        printf "DISPLAY_MANAGER='%s'\n"       "$(state_get DISPLAY_MANAGER none)"
        printf "AUDIO_STACK='%s'\n"           "$(state_get AUDIO_STACK pipewire)"
        printf "SWAP_ENABLED='%s'\n"          "$(state_get SWAP_ENABLED none)"
        printf "SWAP_SIZE='%s'\n"             "$(state_get SWAP_SIZE 0)"
        printf "ZRAM_PERCENT='%s'\n"          "$(state_get ZRAM_PERCENT 50)"
        printf "EXTRAS='%s'\n"                "$(state_get EXTRAS '')"
        printf "KERNEL_CHOICE='%s'\n"         "$(state_get KERNEL_CHOICE linux)"
        printf "KERNEL_IMAGE='%s'\n"          "$(state_get KERNEL_IMAGE '')"
        printf "INITRAMFS_IMAGE='%s'\n"       "$(state_get INITRAMFS_IMAGE '')"
        printf "MICROCODE_IMAGE='%s'\n"       "$(state_get MICROCODE_IMAGE '')"
        printf "MICROCODE_OVERRIDE='%s'\n"    "$(state_get MICROCODE_OVERRIDE auto)"
        printf "HOSTNAME='%s'\n"              "$(state_get HOSTNAME artix)"
        printf "TIMEZONE='%s'\n"              "$(state_get TIMEZONE Europe/Belgrade)"
        printf "LOCALE='%s'\n"                "$(state_get LOCALE en_US.UTF-8)"
        printf "KEYMAP='%s'\n"                "$(state_get KEYMAP us)"
        printf "BTRFS_LAYOUT='%s'\n"          "$(state_get BTRFS_LAYOUT standard)"
        printf "WM_DE='%s'\n"                 "$(state_get WM_DE none)"
        printf "KDE_PROFILE='%s'\n"           "$(state_get KDE_PROFILE desktop)"
        printf "ROOT_PASS='%s'\n"             "$(state_get ROOT_PASS '')"
        printf "USER_COUNT='%s'\n"            "$(state_get USER_COUNT 1)"
        for ((i=1; i<=user_count; i++)); do
            printf "USER_%d_NAME='%s'\n"   "$i" "$(state_get "USER_${i}_NAME" "")"
            printf "USER_%d_PASS='%s'\n"   "$i" "$(state_get "USER_${i}_PASS" "")"
            printf "USER_%d_SHELL='%s'\n"  "$i" "$(state_get "USER_${i}_SHELL" "/bin/bash")"
            printf "USER_%d_GROUPS='%s'\n" "$i" "$(state_get "USER_${i}_GROUPS" "wheel,audio,video,storage")"
            printf "USER_%d_SUDO='%s'\n"   "$i" "$(state_get "USER_${i}_SUDO" "yes")"
        done
        printf "USER_SHELL='%s'\n"            "$(state_get USER_SHELL /bin/bash)"
        printf "PRIV_ESCALATION='%s'\n"       "$(state_get PRIV_ESCALATION sudo)"
        printf "NETWORK_STACK='%s'\n"         "$(state_get NETWORK_STACK dhcpcd+iwd)"
        printf "ALLOW_OFFLINE='%s'\n"         "$(state_get ALLOW_OFFLINE no)"
        printf "X_STACK='%s'\n"               "$(state_get X_STACK xorg)"
        printf "ENABLE_ARCH_REPOS='%s'\n"     "$(state_get ENABLE_ARCH_REPOS no)"
        printf "GENERATE_UKI='%s'\n"          "$(state_get GENERATE_UKI no)"
        printf "USE_LVM='%s'\n"               "$(state_get USE_LVM no)"
        printf "KEEP_BINARY_KERNEL='%s'\n"    "$(state_get KEEP_BINARY_KERNEL yes)"
        printf "COREUTILS='%s'\n"             "$(state_get COREUTILS gnu)"
        printf "KERNEL_CONFIG_DEPTH='%s'\n"   "$(state_get KERNEL_CONFIG_DEPTH auto)"
        printf "QUICK_INSTALL='%s'\n"         "$(state_get QUICK_INSTALL no)"
        printf "POWER_USER='%s'\n"            "$(state_get POWER_USER no)"
        printf "POWERUSER_PACKAGES='%s'\n"    "$(state_get POWERUSER_PACKAGES '')"
        printf "POWERUSER_PROFILE='%s'\n"     "$(state_get POWERUSER_PROFILE default)"
        printf "GUI_MODE='%s'\n"              "$(state_get GUI_MODE no)"
        printf "ENABLE_AURIS='%s'\n"          "$(state_get ENABLE_AURIS no)"
        printf "LUKS_KEYFILE='%s'\n"          "$(state_get LUKS_KEYFILE no)"
        printf "LUKS_KEYFILE_PATH='%s'\n"     "$(state_get LUKS_KEYFILE_PATH '')"
        printf "ISO_ARCH_REPOS='%s'\n"        "$(state_get ISO_ARCH_REPOS no)"
        printf "ARTIX_BOOT_MODE='%s'\n"       "$(state_get ARTIX_BOOT_MODE uefi)"
        printf "TKG_SCHEDULER='%s'\n"         "$(state_get TKG_SCHEDULER eevdf)"
        printf "TKG_BINARY='%s'\n"            "$(state_get TKG_BINARY no)"
        printf "TKG_COMPILER='%s'\n"          "$(state_get TKG_COMPILER gcc)"
        printf "TKG_OPTLEVEL='%s'\n"          "$(state_get TKG_OPTLEVEL 1)"
        printf "TKG_PROCESSOR_OPT='%s'\n"     "$(state_get TKG_PROCESSOR_OPT native)"
        printf "TKG_LTO_MODE='%s'\n"          "$(state_get TKG_LTO_MODE no)"
        printf "TKG_PREEMPT_RT='%s'\n"        "$(state_get TKG_PREEMPT_RT 0)"
        printf "TKG_TICKLESS='%s'\n"          "$(state_get TKG_TICKLESS 2)"
        printf "TKG_TIMER_FREQ='%s'\n"        "$(state_get TKG_TIMER_FREQ 1000)"
        printf "TKG_CPU_GOV='%s'\n"           "$(state_get TKG_CPU_GOV ondemand)"
        printf "TKG_GLITCHED_BASE='%s'\n"     "$(state_get TKG_GLITCHED_BASE false)"
        printf "TKG_ZENIFY='%s'\n"            "$(state_get TKG_ZENIFY false)"
        printf "TKG_CLEAR_PATCHES='%s'\n"     "$(state_get TKG_CLEAR_PATCHES false)"
        printf "TKG_OPENRGB='%s'\n"           "$(state_get TKG_OPENRGB false)"
        printf "TKG_ACS_OVERRIDE='%s'\n"      "$(state_get TKG_ACS_OVERRIDE false)"
        printf "TKG_FSYNC='%s'\n"             "$(state_get TKG_FSYNC false)"
        printf "TKG_MGLRU='%s'\n"             "$(state_get TKG_MGLRU false)"
        printf "TKG_NTSYNC='%s'\n"            "$(state_get TKG_NTSYNC false)"
        printf "TKG_NR_CPUS='%s'\n"           "$(state_get TKG_NR_CPUS "$(nproc)")"
        printf "KERNEL_ADV_FS='%s'\n"         "$(state_get KERNEL_ADV_FS ext4)"
        printf "KERNEL_ADV_GPU='%s'\n"        "$(state_get KERNEL_ADV_GPU '')"
        printf "KERNEL_ADV_NET='%s'\n"        "$(state_get KERNEL_ADV_NET '')"
        printf "KERNEL_ADV_SOUND='%s'\n"      "$(state_get KERNEL_ADV_SOUND '')"
        printf "KERNEL_ADV_USB='%s'\n"        "$(state_get KERNEL_ADV_USB '')"
        printf "KERNEL_ADV_SECURITY='%s'\n"   "$(state_get KERNEL_ADV_SECURITY '')"
        printf "KERNEL_ADV_VIRT='%s'\n"       "$(state_get KERNEL_ADV_VIRT '')"
        printf "KERNEL_ADV_DEBUG='%s'\n"      "$(state_get KERNEL_ADV_DEBUG '')"
        printf "KERNEL_PREEMPT='%s'\n"        "$(state_get KERNEL_PREEMPT voluntary)"
        printf "KERNEL_TIMER='%s'\n"          "$(state_get KERNEL_TIMER 250)"
        printf "KERNEL_GOVERNOR='%s'\n"       "$(state_get KERNEL_GOVERNOR schedutil)"
    } > "${tmp_state}"
    mv "${tmp_state}" "${STATE_FILE}"
    chmod 600 "${STATE_FILE}"
}

state_load() {
    [[ -f "${STATE_FILE}" ]] || return 0
    source "${STATE_FILE}"
}

state_get() {
    local key="${1}"
    local default="${2:-}"
    if [[ -f "${STATE_FILE}" ]]; then
        local value
        value=$(grep "^${key}=" "${STATE_FILE}" 2>/dev/null || true | tail -1 | sed "s|^${key}=||")
        if [[ -n "${value}" ]]; then
            while true; do
                local changed=0
                if [[ "${value}" == \'*\' ]]; then
                    value="${value#\'}"
                    value="${value%\'}"
                    changed=1
                fi
                if [[ "${value}" == ${key}=* ]]; then
                    value="${value#${key}=}"
                    changed=1
                fi
                [[ $changed -eq 0 ]] && break
            done
            printf '%s\n' "${value}"
            return 0
        fi
    fi
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