#!/usr/bin/env bash
set -Eeuo pipefail

_afhub_data_ready=""

_afhub_prepare_data() {
    [[ -n "${_afhub_data_ready}" ]] && return 0

    local data_dir="/tmp/artix-installer/filly-data"
    mkdir -p "${data_dir}"

    if [[ ! -f "${data_dir}/kernels.txt" ]]; then
        cat <<'KERNELS' > "${data_dir}/kernels.txt"
linux
linux-zen
linux-lts
linux-hardened
linux-libre
linux-cachyos
linux-cachyos-bore
linux-cachyos-eevdf
linux-cachyos-bmq
linux-cachyos-rt-bore
linux-cachyos-hardened
linux-cachyos-lts
linux-cachyos-server
linux-cachyos-deckify
linux-bazzite-bin
xanmod
tkg
KERNELS
    fi

    if [[ ! -f "${data_dir}/extras.txt" ]]; then
        pacman -Sl world galaxy 2>/dev/null | awk '{print $2}' | sort -u > "${data_dir}/extras.txt"
    fi

    if [[ ! -f "${data_dir}/timezones.txt" ]]; then
        find /usr/share/zoneinfo -type f 2>/dev/null \
            | sed 's|/usr/share/zoneinfo/||' | grep -v 'posix\|right\|Etc' | sort \
            > "${data_dir}/timezones.txt"
    fi

    if [[ ! -f "${data_dir}/locales.txt" ]]; then
        grep -v '^#' /etc/locale.gen 2>/dev/null | awk '{print $1}' | sort > "${data_dir}/locales.txt"
        [[ -s "${data_dir}/locales.txt" ]] || printf 'en_US.UTF-8\nen_GB.UTF-8\n' > "${data_dir}/locales.txt"
    fi

    if [[ ! -f "${data_dir}/keymaps.txt" ]]; then
        localectl list-keymaps 2>/dev/null | sort > "${data_dir}/keymaps.txt"
        [[ -s "${data_dir}/keymaps.txt" ]] || printf 'us\nuk\nde\nfr\n' > "${data_dir}/keymaps.txt"
    fi

    _afhub_data_ready="1"
}

_sanity_warnings() {
    local -a warnings=()

    local wm_de x_stack dm
    wm_de="$(state_get WM_DE none)"
    x_stack="$(state_get X_STACK xorg)"
    dm="$(state_get DISPLAY_MANAGER none)"

    [[ "${dm}" == "none" && "${wm_de}" != "none" && "${wm_de}" != "hyprland" && "${wm_de}" != "sway" && "${wm_de}" != "niri" && "${wm_de}" != "mango" && "${wm_de}" != "cosmic" ]] && \
        warnings+=("No display manager — you will start the desktop manually")

    [[ "${dm}" == "sddm" && "${x_stack}" == "xlibre" ]] && \
        warnings+=("SDDM may have issues with xlibre — LightDM is recommended for xlibre")

    local wayland_desktops="hyprland sway niri mango cosmic"
    [[ " ${wayland_desktops} " =~ " ${wm_de} " && "${dm}" == "sddm" ]] && \
        warnings+=("SDDM runs under X11 — Wayland compositor will start a nested X server for the login screen")

    local fs_type bootloader
    fs_type="$(state_get FS_TYPE ext4)"
    bootloader="$(state_get BOOTLOADER grub)"

    [[ "${fs_type}" == "xfs" && "${bootloader}" == "grub" ]] && \
        warnings+=("XFS + GRUB: if bigtime is enabled, GRUB may fail to read the filesystem")

    [[ "${fs_type}" == "f2fs" && "${bootloader}" == "grub" ]] && \
        warnings+=("F2FS + GRUB: GRUB may not support F2FS features — verify after install")

    local use_luks use_lvm
    use_luks="$(state_get USE_LUKS no)"
    use_lvm="$(state_get USE_LVM no)"

    [[ "${use_luks}" == "yes" && "${bootloader}" == "efistub" ]] && \
        warnings+=("LUKS + EFIStub: you must include 'cryptdevice=' in kernel cmdline manually")

    [[ "${use_luks}" == "yes" && "${use_lvm}" == "yes" && "${bootloader}" == "limine" ]] && \
        warnings+=("LUKS-on-LVM + Limine: untested combination — verify boot after install")

    [[ "$(state_get NETWORK_STACK)" == "none" && "$(state_get ALLOW_OFFLINE)" != "yes" ]] && \
        warnings+=("No network stack and not offline — you will have no internet after boot")

    local user_count root_pass
    user_count="$(state_get USER_COUNT 0)"
    root_pass="$(state_get ROOT_PASS '')"

    [[ "${user_count}" -eq 0 && -z "${root_pass}" ]] && \
        warnings+=("No users and no root password — system will have no way to log in")

    [[ -z "${root_pass}" && "${user_count}" -gt 0 && "$(state_get PRIV_ESCALATION)" == "none" ]] && \
        warnings+=("No root password and no privilege escalation — you cannot gain root after install")

    [[ "$(state_get POWER_USER)" == "yes" && "$(state_get KEEP_BINARY_KERNEL)" == "no" ]] && \
        warnings+=("No fallback kernel — system may be unbootable if custom kernel fails")

    [[ "$(state_get POWER_USER)" == "yes" && " $(state_get POWERUSER_PACKAGES) " =~ " glibc " ]] && \
        warnings+=("glibc from source is DANGEROUS — a miscompilation breaks everything")

    [[ "$(state_get POWER_USER)" == "yes" && "$(state_get INIT)" == "busybox" ]] && \
        warnings+=("BusyBox init from source — ensure the recipe compiled successfully")

    [[ "$(state_get PRIV_ESCALATION)" == "doas" && "$(state_get POWER_USER)" == "yes" ]] && \
        warnings+=("doas + Power User: anvil commands require root — use 'doas anvil ...'")

    [[ "$(state_get ALLOW_OFFLINE)" == "yes" ]] && \
        warnings+=("Offline mode — packages may be outdated or missing")

    [[ "$(state_get ALLOW_OFFLINE)" == "yes" && "$(state_get POWER_USER)" == "yes" ]] && \
        warnings+=("Offline + Power User: source downloads will fail without internet — fetch sources first")

    [[ "$(state_get ENABLE_ARCH_REPOS)" == "yes" ]] && \
        warnings+=("Arch repositories enabled — partial upgrades may cause breakage if Artix and Arch diverge")

    [[ "${wm_de}" == "cosmic" ]] && \
        warnings+=("COSMIC is alpha software — expect bugs, crashes, and missing features")

    [[ "${wm_de}" == "mango" ]] && \
        warnings+=("MangoWM requires Chaotic-AUR — this repository is not officially supported by Artix")

    [[ -d /mnt/etc/runit && "$(state_get INIT)" != "runit" ]] && \
        warnings+=("runit service directories found but init is $(state_get INIT) — leftover migration artifacts")

    [[ -d /mnt/etc/dinit.d && "$(state_get INIT)" != "dinit" ]] && \
        warnings+=("dinit service directories found but init is $(state_get INIT) — leftover migration artifacts")

    [[ "$(state_get PRIV_ESCALATION)" == "none" ]] && \
        warnings+=("No privilege escalation tool — you will need to configure su manually")

    if [[ ${#warnings[@]} -gt 0 ]]; then
        local msg
        msg=$(printf ' - %s\n' "${warnings[@]}")
        if ! tui_yesno "Sanity Warnings" "${msg}\n\nProceed anyway?"; then
            return 1
        fi
    fi
    return 0
}

_launch_disk_partitioner() {
    local disk
    disk="$(state_get DISK '')"
    [[ -n "${disk}" && -b "${disk}" ]] || { tui_msg_quick "No Disk" "Select a target disk first."; return 1; }

    local result
    result=$(tui_disk "Partition ${disk}" "${disk}" "[]" "[]" "false")

    [[ -z "${result}" ]] && return 1

    local partitions_free
    partitions_free=$(echo "${result}" | jq -c '{partitions: .partitions, free_space: .free_space}')

    state_set EFI_PART ""
    state_set ROOT_PART ""
    state_set SWAP_PART ""

    local part_count
    part_count=$(echo "${partitions_free}" | jq '.partitions | length')
    for ((i=0; i<part_count; i++)); do
        local ptype pnum pstart
        ptype=$(echo "${partitions_free}" | jq -r ".partitions[${i}].type")
        pnum=$(echo "${partitions_free}" | jq -r ".partitions[${i}].number")
        pstart=$(echo "${partitions_free}" | jq -r ".partitions[${i}].start")

        case "${ptype}" in
            "EFI System")
                state_set EFI_PART "$(get_partition_name "${disk}" "${pnum}")"
                ;;
            "Linux swap")
                state_set SWAP_PART "$(get_partition_name "${disk}" "${pnum}")"
                state_set SWAP_ENABLED "partition"
                ;;
            "Linux filesystem"|"Linux /boot"|"Linux /home"|"Linux /var"|"Linux /tmp")
                [[ -z "$(state_get ROOT_PART '')" ]] && state_set ROOT_PART "$(get_partition_name "${disk}" "${pnum}")"
                ;;
        esac
    done

    [[ -z "$(state_get ROOT_PART '')" && ${part_count} -gt 0 ]] && \
        state_set ROOT_PART "$(get_partition_name "${disk}" 1)"

    tui_msg_quick "Partitions Set" "Partition layout saved. EFI: $(state_get EFI_PART 'auto'), Root: $(state_get ROOT_PART 'auto')"
}

_validate_config_file() {
    local file="${1}"
    local errors=""

    [[ -f "${file}" ]] || { echo "File not found: ${file}"; return 1; }
    [[ -s "${file}" ]] || { echo "File is empty: ${file}"; return 1; }

    local -a required_keys=(DISK FS_TYPE INIT BOOTLOADER KERNEL_CHOICE)
    local -a found_keys=()

    while IFS='=' read -r key value; do
        [[ -z "${key}" || "${key}" == \#* ]] && continue
        found_keys+=("${key}")
    done < "${file}"

    for key in "${required_keys[@]}"; do
        local found=0
        for fk in "${found_keys[@]}"; do
            [[ "${fk}" == "${key}" ]] && found=1 && break
        done
        [[ ${found} -eq 0 ]] && errors+="Missing required key: ${key}"$'\n'
    done

    local disk_value
    disk_value=$(grep "^DISK=" "${file}" | head -n1 | cut -d= -f2- | tr -d "'\"")
    if [[ -n "${disk_value}" ]] && [[ ! -b "${disk_value}" ]]; then
        errors+="DISK '${disk_value}' is not a valid block device"$'\n'
    fi

    local fs_value
    fs_value=$(grep "^FS_TYPE=" "${file}" | head -n1 | cut -d= -f2- | tr -d "'\"")
    if [[ -n "${fs_value}" ]]; then
        case "${fs_value}" in
            ext4|btrfs|xfs|f2fs) ;;
            *) errors+="FS_TYPE '${fs_value}' is not supported (ext4, btrfs, xfs, f2fs)"$'\n' ;;
        esac
    fi

    local init_value
    init_value=$(grep "^INIT=" "${file}" | head -n1 | cut -d= -f2- | tr -d "'\"")
    if [[ -n "${init_value}" ]]; then
        case "${init_value}" in
            openrc|runit|dinit|s6|busybox) ;;
            *) errors+="INIT '${init_value}' is not a supported init system"$'\n' ;;
        esac
    fi

    if [[ -n "${errors}" ]]; then
        echo "${errors}"
        return 1
    fi

    return 0
}

_load_config_preset() {
    local preset_dir="${BASE_DIR}/presets"
    [[ -d "${preset_dir}" ]] || mkdir -p "${preset_dir}"

    local chosen_file
    chosen_file=$(tui_file_picker "Select Config" "${preset_dir}" "conf") || return 0

    if [[ -z "${chosen_file}" || ! -f "${chosen_file}" ]]; then
        return 0
    fi

    local validation_errors
    validation_errors=$(_validate_config_file "${chosen_file}")
    if [[ $? -ne 0 ]]; then
        tui_msg "Invalid Config" "The selected file has errors:\n\n${validation_errors}"
        return 0
    fi

    while IFS='=' read -r key value; do
        [[ -z "${key}" || "${key}" == \#* ]] && continue
        value="${value#\'}"; value="${value%\'}"
        value="${value#\"}"; value="${value%\"}"
        state_set "${key}" "${value}"
    done < "${chosen_file}"

    local preset_name
    preset_name=$(basename "${chosen_file}" .conf)
    tui_msg_quick "Config Loaded" "Configuration '${preset_name}' loaded.\n\nReview and adjust in the hub, then press Proceed."
}

tui_afhub() {
    _afhub_prepare_data

    local data_dir="/tmp/artix-installer/filly-data"
    local disk_choices_json
    disk_choices_json=$(lsblk -dpno NAME,SIZE,MODEL -e 7 2>/dev/null \
        | awk '{printf "%s - %s %s\n", $1, $2, $3}' \
        | jq -R . | jq -s -c .)

    local bootloader_choices='["grub","refind","efistub","limine"]'
    if [[ "${ARTIX_BOOT_MODE:-uefi}" == "bios" ]]; then
        bootloader_choices='["grub","limine"]'
    fi

    local cats_json
    cats_json=$(cat <<JSONEOF
[
  {"id":"disk","label":"Disk & Storage","summary_template":"fs: {FS_TYPE}, swap: {SWAP_ENABLED}","items":[
    {"id":"DISK","label":"Target disk","value":"$(state_get DISK '')","widget":"menu","choices":${disk_choices_json},"message":"Select the target drive for installation"},
    {"id":"DISK_PARTITIONER","label":"Partition editor","value":"","widget":"menu","choices":["Use whole disk","Edit partitions manually"],"message":"Configure partitions on the selected disk before installing"},
    {"id":"FS_TYPE","label":"Filesystem","value":"$(state_get FS_TYPE ext4)","widget":"menu","choices":["ext4","btrfs","xfs","f2fs"],"message":"Choose the root filesystem type"},
    {"id":"SWAP_ENABLED","label":"Swap type","value":"$(state_get SWAP_ENABLED none)","widget":"menu","choices":["none","partition","swapfile","zram","zswap"],"message":"Select swap configuration"},
    {"id":"SWAP_SIZE","label":"Swap size","value":"$(state_get SWAP_SIZE 0)","widget":"input","placeholder":"e.g. 4G or 4096","visible_if":{"SWAP_ENABLED":"partition,swapfile"},"message":"Enter swap partition or swapfile size"},
    {"id":"ZRAM_PERCENT","label":"ZRAM percent","value":"$(state_get ZRAM_PERCENT 50)","widget":"input","placeholder":"e.g. 50","visible_if":{"SWAP_ENABLED":"zram"},"message":"Percentage of RAM to use for zram"},
    {"id":"USE_LUKS","label":"LUKS encryption","value":"$(state_get USE_LUKS no)","widget":"yesno","message":"Encrypt the entire installation with LUKS?\\nYou will be prompted for a passphrase."},
    {"id":"LUKS_PASS","label":"LUKS password","value":"$(state_get LUKS_PASS '')","widget":"password_confirm","visible_if":{"USE_LUKS":"yes"},"message":"Set the disk encryption passphrase (you will need this to unlock the system at boot)"},
    {"id":"USE_LVM","label":"LVM","value":"$(state_get USE_LVM no)","widget":"yesno","message":"Use Logical Volume Manager for flexible partitioning?"},
    {"id":"BTRFS_LAYOUT","label":"BTRFS layout","value":"$(state_get BTRFS_LAYOUT standard)","widget":"menu","choices":["standard","flat","snapshot"],"visible_if":{"FS_TYPE":"btrfs"},"message":"Select BTRFS subvolume layout"}
  ]},
  {"id":"bootloader","label":"Bootloader","summary_template":"{BOOTLOADER}, UKI: {GENERATE_UKI}","items":[
    {"id":"BOOTLOADER","label":"Bootloader","value":"$(state_get BOOTLOADER grub)","widget":"menu","choices":${bootloader_choices},"message":"Select the bootloader for starting the system"},
    {"id":"GENERATE_UKI","label":"Unified Kernel Image","value":"$(state_get GENERATE_UKI no)","widget":"yesno","message":"Generate a UKI (single .efi file) for Secure Boot compatibility?"}
  ]},
  {"id":"kernel","label":"Kernel & Microcode","summary_template":"{KERNEL_CHOICE}","items":[
    {"id":"KERNEL_CHOICE","label":"Kernel","value":"$(state_get KERNEL_CHOICE linux)","widget":"filter","choices_file":"kernels.txt","message":"Select the Linux kernel to install"},
    {"id":"MICROCODE_OVERRIDE","label":"Microcode","value":"$(state_get MICROCODE_OVERRIDE auto)","widget":"menu","choices":["auto","intel-ucode","amd-ucode","none"],"message":"CPU microcode updates for security and stability"}
  ]},
  {"id":"init","label":"Init System","summary_template":"{INIT}","items":[
    {"id":"INIT","label":"Init system","value":"$(state_get INIT openrc)","widget":"menu","choices":["openrc","runit","dinit","s6"],"message":"Select the init system (PID 1) for service management"}
  ]},
  {"id":"desktop","label":"Desktop","summary_template":"{WM_DE}, dm: {DISPLAY_MANAGER}","items":[
    {"id":"WM_DE","label":"Desktop / WM","value":"$(state_get WM_DE none)","widget":"menu","choices":["kde","sonicde","xfce4","lxqt","lxde","hyprland","sway","niri","i3wm","dwm","vxwm","icewm","mango","cinnamon","budgie","moksha","cosmic","none"],"message":"Select your desktop environment or window manager"},
    {"id":"DISPLAY_MANAGER","label":"Display Manager","value":"$(state_get DISPLAY_MANAGER none)","widget":"menu","choices":["none","lightdm","sddm","soniclogin"],"message":"Graphical login screen (select 'none' for startx)"},
    {"id":"X_STACK","label":"Display Stack","value":"$(state_get X_STACK xorg)","widget":"menu","choices":["xlibre","xorg"],"message":"Display server stack (xlibre is Artix's recommended X11)"}
  ]},
  {"id":"network_audio","label":"Network & Audio","summary_template":"net: {NETWORK_STACK}, aud: {AUDIO_STACK}","items":[
    {"id":"NETWORK_STACK","label":"Network stack","value":"$(state_get NETWORK_STACK networkmanager)","widget":"menu","choices":["networkmanager","dhcpcd+iwd","connman","none"],"message":"How should the system connect to networks?"},
    {"id":"AUDIO_STACK","label":"Audio stack","value":"$(state_get AUDIO_STACK pipewire)","widget":"menu","choices":["pipewire","pulseaudio","none"],"message":"Sound server (PipeWire is recommended)"}
  ]},
  {"id":"users","label":"Users & Privilege","summary_template":"priv: {PRIV_ESCALATION}","items":[
    {"id":"USER_MANAGER","label":"User accounts","value":"","widget":"user_manager","message":"Add, edit, or remove user accounts"},
    {"id":"ROOT_PASS","label":"Root password","value":"$(state_get ROOT_PASS '')","widget":"password_confirm","message":"Set the root (administrator) password"},
    {"id":"PRIV_ESCALATION","label":"Privilege escalation","value":"$(state_get PRIV_ESCALATION sudo)","widget":"menu","choices":["sudo","doas"],"message":"How will users run commands as root?"},
    {"id":"USER_SHELL","label":"Default shell","value":"$(state_get USER_SHELL bash)","widget":"menu","choices":["bash","zsh","fish"],"message":"Default command shell for new users"}
  ]},
  {"id":"extras","label":"Extras & Repos","summary_template":"arch: {ENABLE_ARCH_REPOS}, pw: {POWER_USER}","items":[
    {"id":"EXTRAS","label":"Extra packages","value":"$(state_get EXTRAS '')","widget":"multiselect","choices_file":"extras.txt","message":"Select additional packages to install"},
    {"id":"ENABLE_ARCH_REPOS","label":"Arch repositories","value":"$(state_get ENABLE_ARCH_REPOS no)","widget":"yesno","message":"Enable Arch Linux repositories for AUR and additional packages?"},
    {"id":"ENABLE_AURIS","label":"AURIS","value":"$(state_get ENABLE_AURIS no)","widget":"yesno","message":"Enable AURIS for AUR package management?"},
    {"id":"ALLOW_OFFLINE","label":"Offline mode","value":"$(state_get ALLOW_OFFLINE no)","widget":"yesno","message":"Allow installation without internet connection?"},
    {"id":"POWER_USER","label":"Power User mode","value":"$(state_get POWER_USER no)","widget":"yesno","message":"Enable source-based package compilation (Gentoo-style)?"}
  ]},
  {"id":"identity","label":"System Identity","summary_template":"host: {HOSTNAME}","items":[
    {"id":"HOSTNAME","label":"Hostname","value":"$(state_get HOSTNAME artix)","widget":"input","placeholder":"Enter hostname","message":"The name of this computer on the network"},
    {"id":"TIMEZONE","label":"Timezone","value":"$(state_get TIMEZONE Europe/Belgrade)","widget":"filter","choices_file":"timezones.txt","message":"Your local timezone for correct clock display"},
    {"id":"LOCALE","label":"Locale","value":"$(state_get LOCALE en_US.UTF-8)","widget":"filter","choices_file":"locales.txt","message":"System language and character encoding"},
    {"id":"KEYMAP","label":"Keyboard layout","value":"$(state_get KEYMAP us)","widget":"filter","choices_file":"keymaps.txt","message":"Keyboard layout for the console"}
  ]},
  {"id":"theme","label":"Theme","summary_template":"{GUM_TITLE_COLOR} / {GUM_ACCENT_COLOR}","items":[
    {"id":"GUM_TITLE_COLOR","label":"Theme","value":"Forge (pink/green)","widget":"menu","choices":["Forge (pink/green)","Artix (blue)","Jet Black (grey)","Mono (white)","Retro (yellow)"],"message":"Colour theme for the installer (also applied to installed system)"}
  ]}
]
JSONEOF
)

    local actions_json='["Quick Profile","Load Config","Proceed"]'
    local result
    result=$(tui_install_hub "Artix Configuration" "${cats_json}" "${actions_json}")

    [[ -z "${result}" ]] && return 1

    printf '%s\n' "${result}"
    return 0
}

tui_collect_install_config() {
    if [[ "${ARTIX_BOOT_MODE:-uefi}" == "bios" ]]; then
        tui_msg_quick "BIOS Mode" "Legacy BIOS boot detected. UEFI features are disabled."
    fi

    state_set DISK            "${DISK:-$(state_get DISK '')}"
    state_set FS_TYPE         "${FS_TYPE:-ext4}"
    state_set BOOTLOADER      "${BOOTLOADER:-grub}"
    state_set KERNEL_CHOICE   "${KERNEL_CHOICE:-linux}"
    state_set INIT            "${INIT:-openrc}"
    state_set WM_DE           "${WM_DE:-none}"
    state_set NETWORK_STACK   "${NETWORK_STACK:-networkmanager}"
    state_set AUDIO_STACK     "${AUDIO_STACK:-pipewire}"
    state_set PRIV_ESCALATION "${PRIV_ESCALATION:-sudo}"
    state_set HOSTNAME        "${HOSTNAME:-artix}"
    state_set TIMEZONE        "${TIMEZONE:-Europe/Belgrade}"
    state_set LOCALE          "${LOCALE:-en_US.UTF-8}"
    state_set KEYMAP          "${KEYMAP:-us}"
    state_set USER_COUNT      "${USER_COUNT:-0}"

    if [[ -z "$(state_get DISK '')" ]]; then
        tui_select_disk
    fi

    local have_config=""
    while [[ -z "${have_config}" ]]; do
        local result
        result=$(tui_afhub) || { tui_msg_quick "Cancelled" "Installation cancelled."; exit 0; }

        if [[ -z "${result}" ]]; then
            tui_msg_quick "Cancelled" "Installation cancelled."
            exit 0
        fi

        local parsed_type
        parsed_type=$(echo "${result}" | jq -r 'type' 2>/dev/null || echo "string")

        if [[ "${parsed_type}" == "object" ]]; then
            local key val
            while IFS= read -r key; do
                [[ -z "${key}" ]] && continue
                val=$(echo "${result}" | jq -r --arg k "${key}" '.[$k]' 2>/dev/null || true)
                [[ -n "${val}" ]] && state_set "${key}" "${val}"
            done <<< "$(echo "${result}" | jq -r 'keys[]')"

            if [[ "$(state_get DISK_PARTITIONER '')" == "Edit partitions manually" ]]; then
                _launch_disk_partitioner
                state_set DISK_PARTITIONER "Use whole disk"
                continue
            fi

            if [[ "$(state_get DISK '')" == "$(state_get PREV_DISK '')" ]]; then
                log_warn "You must select a target disk before proceeding."
                tui_msg_quick "Disk Required" "Please select a target disk in the 'Disk & Storage' category."
                continue
            fi
            state_set PREV_DISK "$(state_get DISK '')"

            if ! _sanity_warnings; then
                continue
            fi

            have_config="1"
        else
            case "${result}" in
                "Quick Profile")
                    continue
                    ;;
                "Load Config")
                    _load_config_preset
                    continue
                    ;;
                *)
                    log_warn "Unexpected hub result: ${result}"
                    continue
                    ;;
            esac
        fi
    done
}

tui_select_disk() {
    local disk disks=()
    while IFS=' ' read -r name size model; do
        disks+=("${name} - ${size} (${model:-Unknown})")
    done < <(lsblk -dpno NAME,SIZE,MODEL -e 7)
    disk=$(tui_menu "Disk Selection" "Choose target drive:" "${disks[@]}") || return 1
    disk="${disk%% *}"
    state_set DISK "${disk}"
}