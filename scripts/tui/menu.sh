#!/usr/bin/env bash
set -Eeuo pipefail

tui_afhub() {
    local cats_json
    cats_json=$(cat <<JSONEOF
[
  {"id":"disk","label":"Disk & Storage","summary_template":"fs: {FS_TYPE}, swap: {SWAP_ENABLED}","items":[
    {"id":"DISK","label":"Target disk","value":"$(state_get DISK '')","widget":"disk_picker","disk_picker":true},
    {"id":"FS_TYPE","label":"Filesystem","value":"$(state_get FS_TYPE ext4)","widget":"menu","choices":["ext4","btrfs","xfs","f2fs"]},
    {"id":"SWAP_ENABLED","label":"Swap","value":"$(state_get SWAP_ENABLED no)","widget":"yesno"},
    {"id":"SWAP_SIZE","label":"Swap size","value":"$(state_get SWAP_SIZE 0)","widget":"input","placeholder":"e.g. 4G","visible_if":{"SWAP_ENABLED":"yes"}},
    {"id":"USE_LUKS","label":"LUKS","value":"$(state_get USE_LUKS no)","widget":"yesno"},
    {"id":"USE_LVM","label":"LVM","value":"$(state_get USE_LVM no)","widget":"yesno"},
    {"id":"BTRFS_LAYOUT","label":"BTRFS layout","value":"$(state_get BTRFS_LAYOUT standard)","widget":"menu","choices":["standard","flat","snapshot"],"visible_if":{"FS_TYPE":"btrfs"}}
  ]},
  {"id":"bootloader","label":"Bootloader","summary_template":"{BOOTLOADER}, UKI: {GENERATE_UKI}","items":[
    {"id":"BOOTLOADER","label":"Bootloader","value":"$(state_get BOOTLOADER grub)","widget":"menu","choices":["grub","refind","efistub","limine"]},
    {"id":"GENERATE_UKI","label":"UKI","value":"$(state_get GENERATE_UKI no)","widget":"yesno"}
  ]},
  {"id":"kernel","label":"Kernel & Microcode","summary_template":"{KERNEL_CHOICE}","items":[
    {"id":"KERNEL_CHOICE","label":"Kernel","value":"$(state_get KERNEL_CHOICE linux)","widget":"kernel_picker"},
    {"id":"MICROCODE_OVERRIDE","label":"Microcode","value":"$(state_get MICROCODE_OVERRIDE auto)","widget":"menu","choices":["auto","intel-ucode","amd-ucode","none"]}
  ]},
  {"id":"init","label":"Init System","summary_template":"{INIT}","items":[
    {"id":"INIT","label":"Init system","value":"$(state_get INIT openrc)","widget":"menu","choices":["openrc","runit","dinit","s6"]}
  ]},
  {"id":"desktop","label":"Desktop","summary_template":"{WM_DE}, dm: {DISPLAY_MANAGER}","items":[
    {"id":"WM_DE","label":"Desktop / WM","value":"$(state_get WM_DE none)","widget":"menu","choices":["kde","sonicde","xfce4","lxqt","lxde","hyprland","sway","niri","i3wm","dwm","vxwm","icewm","mango","cinnamon","budgie","moksha","cosmic","none"]},
    {"id":"DISPLAY_MANAGER","label":"Display Manager","value":"$(state_get DISPLAY_MANAGER none)","widget":"menu","choices":["none","lightdm","sddm","soniclogin"]},
    {"id":"X_STACK","label":"Display Stack","value":"$(state_get X_STACK xorg)","widget":"menu","choices":["xlibre","xorg"]}
  ]},
  {"id":"network_audio","label":"Network & Audio","summary_template":"net: {NETWORK_STACK}, aud: {AUDIO_STACK}","items":[
    {"id":"NETWORK_STACK","label":"Network stack","value":"$(state_get NETWORK_STACK networkmanager)","widget":"menu","choices":["networkmanager","dhcpcd+iwd","connman","none"]},
    {"id":"AUDIO_STACK","label":"Audio stack","value":"$(state_get AUDIO_STACK pipewire)","widget":"menu","choices":["pipewire","pulseaudio","none"]}
  ]},
  {"id":"users","label":"Users & Privilege","summary_template":"priv: {PRIV_ESCALATION}","items":[
    {"id":"USER_COUNT","label":"User accounts","value":"$(state_get USER_COUNT 0)","widget":"user_manager"},
    {"id":"ROOT_PASS","label":"Root password","value":"$(state_get ROOT_PASS '')","widget":"password","display":"set/not set"},
    {"id":"PRIV_ESCALATION","label":"Privilege escalation","value":"$(state_get PRIV_ESCALATION sudo)","widget":"menu","choices":["sudo","doas"]},
    {"id":"USER_SHELL","label":"User shell","value":"$(state_get USER_SHELL bash)","widget":"menu","choices":["bash","zsh","fish"]}
  ]},
  {"id":"extras","label":"Extras & Repos","summary_template":"arch: {ENABLE_ARCH_REPOS}, pw: {POWER_USER}","items":[
    {"id":"EXTRAS","label":"Extra packages","value":"$(state_get EXTRAS '')","widget":"multiselect","choices":[],"choices_from":"pacman -Sl world galaxy | awk \"{print \$2}\" | sort -u"},
    {"id":"ENABLE_ARCH_REPOS","label":"Arch repositories","value":"$(state_get ENABLE_ARCH_REPOS no)","widget":"yesno"},
    {"id":"ENABLE_AURIS","label":"AURIS","value":"$(state_get ENABLE_AURIS no)","widget":"yesno"},
    {"id":"ALLOW_OFFLINE","label":"Offline mode","value":"$(state_get ALLOW_OFFLINE no)","widget":"yesno"},
    {"id":"POWER_USER","label":"Power User mode","value":"$(state_get POWER_USER no)","widget":"yesno"}
  ]},
  {"id":"identity","label":"System Identity","summary_template":"host: {HOSTNAME}","items":[
    {"id":"HOSTNAME","label":"Hostname","value":"$(state_get HOSTNAME artix)","widget":"input"},
    {"id":"TIMEZONE","label":"Timezone","value":"$(state_get TIMEZONE Europe/Belgrade)","widget":"filter","placeholder":"Type to search timezones..."},
    {"id":"LOCALE","label":"Locale","value":"$(state_get LOCALE en_US.UTF-8)","widget":"filter","placeholder":"Type to search locales..."},
    {"id":"KEYMAP","label":"Keyboard layout","value":"$(state_get KEYMAP us)","widget":"filter","placeholder":"Type to search keymaps..."}
  ]},
  {"id":"theme","label":"Theme","summary_template":"{GUM_TITLE_COLOR} / {GUM_ACCENT_COLOR}","items":[
    {"id":"GUM_TITLE_COLOR","label":"Theme","value":"Forge (pink/green)","widget":"menu","choices":["Forge (pink/green)","Artix (blue)","Jet Black (grey)","Mono (white)","Retro (yellow)"]}
  ]}
]
JSONEOF
)

    local actions_json='["Quick Profile","Proceed"]'
    local result
    result=$(tui_hub "ArtixForge Configuration" "${cats_json}" "${actions_json}")

    [[ -z "${result}" ]] && return 1

    local data
    data=$(echo "${result}" | jq -r '.result // empty')
    [[ -z "${data}" ]] && return 1

    if echo "${data}" | jq -e 'type == "string"' &>/dev/null; then
        echo "${data}"
        return 0
    fi

    local action
    action=$(echo "${data}" | jq -r '._action // empty' 2>/dev/null)
    if [[ -n "${action}" ]]; then
        echo "${action}"
        return 0
    fi

    local key val
    while IFS= read -r key; do
        [[ -z "${key}" ]] && continue
        val=$(echo "${data}" | jq -r --arg k "${key}" '.[$k]')
        state_set "${key}" "${val}"
    done <<< "$(echo "${data}" | jq -r 'keys[]')"

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