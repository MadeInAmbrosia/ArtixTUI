#!/usr/bin/env bash
set -Eeuo pipefail

tui_afhub() {
    local disk_choices_json kernel_choices_json extras_choices_json
    local tz_choices_json locale_choices_json keymap_choices_json

    disk_choices_json=$(lsblk -dpno NAME,SIZE,MODEL -e 7 2>/dev/null \
        | awk '{printf "%s - %s %s\n", $1, $2, $3}' \
        | jq -R . | jq -s .)

    kernel_choices_json=$(cat <<'KERNELS' | jq -R . | jq -s .
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
)

    extras_choices_json=$(pacman -Sl world galaxy 2>/dev/null | awk '{print $2}' | sort -u | jq -R . | jq -s .)

    tz_choices_json=$(find /usr/share/zoneinfo -type f 2>/dev/null \
        | sed 's|/usr/share/zoneinfo/||' | grep -v 'posix\|right\|Etc' | sort \
        | jq -R . | jq -s .)

    locale_choices_json=$(grep -v '^#' /etc/locale.gen 2>/dev/null | awk '{print $1}' | sort | jq -R . | jq -s .)
    [[ -z "$locale_choices_json" || "$locale_choices_json" == "[]" ]] && locale_choices_json='["en_US.UTF-8","en_GB.UTF-8"]'

    keymap_choices_json=$(localectl list-keymaps 2>/dev/null | sort | jq -R . | jq -s .)
    [[ -z "$keymap_choices_json" || "$keymap_choices_json" == "[]" ]] && keymap_choices_json='["us","uk","de","fr"]'

    local cats_json
    cats_json=$(cat <<JSONEOF
[
  {"id":"disk","label":"Disk & Storage","summary_template":"fs: {FS_TYPE}, swap: {SWAP_ENABLED}","items":[
    {"id":"DISK","label":"Target disk","value":"$(state_get DISK '')","widget":"menu","choices":${disk_choices_json},"message":"Select the target drive for installation"},
    {"id":"FS_TYPE","label":"Filesystem","value":"$(state_get FS_TYPE ext4)","widget":"menu","choices":["ext4","btrfs","xfs","f2fs"],"message":"Choose the root filesystem type"},
    {"id":"SWAP_ENABLED","label":"Swap","value":"$(state_get SWAP_ENABLED no)","widget":"yesno","message":"Enable swap space?"},
    {"id":"SWAP_SIZE","label":"Swap size","value":"$(state_get SWAP_SIZE 0)","widget":"input","placeholder":"e.g. 4G","visible_if":{"SWAP_ENABLED":"yes"},"message":"Enter swap partition size"},
    {"id":"USE_LUKS","label":"LUKS encryption","value":"$(state_get USE_LUKS no)","widget":"yesno","message":"Encrypt the entire installation with LUKS?\nYou will be prompted for a passphrase."},
    {"id":"USE_LVM","label":"LVM","value":"$(state_get USE_LVM no)","widget":"yesno","message":"Use Logical Volume Manager for flexible partitioning?"},
    {"id":"BTRFS_LAYOUT","label":"BTRFS layout","value":"$(state_get BTRFS_LAYOUT standard)","widget":"menu","choices":["standard","flat","snapshot"],"visible_if":{"FS_TYPE":"btrfs"},"message":"Select BTRFS subvolume layout"}
  ]},
  {"id":"bootloader","label":"Bootloader","summary_template":"{BOOTLOADER}, UKI: {GENERATE_UKI}","items":[
    {"id":"BOOTLOADER","label":"Bootloader","value":"$(state_get BOOTLOADER grub)","widget":"menu","choices":["grub","refind","efistub","limine"],"message":"Select the bootloader for starting the system"},
    {"id":"GENERATE_UKI","label":"Unified Kernel Image","value":"$(state_get GENERATE_UKI no)","widget":"yesno","message":"Generate a UKI (single .efi file) for Secure Boot compatibility?"}
  ]},
  {"id":"kernel","label":"Kernel & Microcode","summary_template":"{KERNEL_CHOICE}","items":[
    {"id":"KERNEL_CHOICE","label":"Kernel","value":"$(state_get KERNEL_CHOICE linux)","widget":"filter","placeholder":"Type to search kernels...","choices":${kernel_choices_json},"message":"Select the Linux kernel to install"},
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
    {"id":"EXTRAS","label":"Extra packages","value":"$(state_get EXTRAS '')","widget":"multiselect","choices":${extras_choices_json},"message":"Select additional packages to install"},
    {"id":"ENABLE_ARCH_REPOS","label":"Arch repositories","value":"$(state_get ENABLE_ARCH_REPOS no)","widget":"yesno","message":"Enable Arch Linux repositories for AUR and additional packages?"},
    {"id":"ENABLE_AURIS","label":"AURIS","value":"$(state_get ENABLE_AURIS no)","widget":"yesno","message":"Enable AURIS for AUR package management?"},
    {"id":"ALLOW_OFFLINE","label":"Offline mode","value":"$(state_get ALLOW_OFFLINE no)","widget":"yesno","message":"Allow installation without internet connection?"},
    {"id":"POWER_USER","label":"Power User mode","value":"$(state_get POWER_USER no)","widget":"yesno","message":"Enable source-based package compilation (Gentoo-style)?"}
  ]},
  {"id":"identity","label":"System Identity","summary_template":"host: {HOSTNAME}","items":[
    {"id":"HOSTNAME","label":"Hostname","value":"$(state_get HOSTNAME artix)","widget":"input","placeholder":"Enter hostname","message":"The name of this computer on the network"},
    {"id":"TIMEZONE","label":"Timezone","value":"$(state_get TIMEZONE Europe/Belgrade)","widget":"filter","placeholder":"Type to search timezones...","choices":${tz_choices_json},"message":"Your local timezone for correct clock display"},
    {"id":"LOCALE","label":"Locale","value":"$(state_get LOCALE en_US.UTF-8)","widget":"filter","placeholder":"Type to search locales...","choices":${locale_choices_json},"message":"System language and character encoding"},
    {"id":"KEYMAP","label":"Keyboard layout","value":"$(state_get KEYMAP us)","widget":"filter","placeholder":"Type to search keymaps...","choices":${keymap_choices_json},"message":"Keyboard layout for the console"}
  ]},
  {"id":"theme","label":"Theme","summary_template":"{GUM_TITLE_COLOR} / {GUM_ACCENT_COLOR}","items":[
    {"id":"GUM_TITLE_COLOR","label":"Theme","value":"Forge (pink/green)","widget":"menu","choices":["Forge (pink/green)","Artix (blue)","Jet Black (grey)","Mono (white)","Retro (yellow)"],"message":"Colour theme for the installer (also applied to installed system)"}
  ]}
]
JSONEOF
)

    local actions_json='["Quick Profile","Proceed"]'
    local result
    result=$(tui_install_hub "ArtixForge Configuration" "${cats_json}" "${actions_json}")

    [[ -z "${result}" ]] && return 1

    if echo "${result}" | jq -e 'type == "string"' &>/dev/null; then
        echo "${result}"
        return 0
    fi

    local action
    action=$(echo "${result}" | jq -r '._action // empty' 2>/dev/null)
    if [[ -n "${action}" ]]; then
        echo "${action}"
        return 0
    fi

    local key val
    while IFS= read -r key; do
        [[ -z "${key}" ]] && continue
        val=$(echo "${result}" | jq -r --arg k "${key}" '.[$k]')
        state_set "${key}" "${val}"
    done <<< "$(echo "${result}" | jq -r 'keys[]')"

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

    while true; do
        local result
        result=$(tui_afhub) || { tui_msg_quick "Cancelled" "Installation cancelled."; exit 0; }

        if [[ -z "${result}" ]]; then
            return 0
        fi

        case "${result}" in
            "Quick Profile")
                continue
                ;;
            *) continue ;;
        esac
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