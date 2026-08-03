#!/usr/bin/env bash
set -Eeuo pipefail

ISO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

tui_iso_hub() {
    local kernel_choices
    if [[ "$(state_get TARGET_ARCH x86_64)" == "aarch64" ]]; then
        kernel_choices='["linux-aarch64","linux-aarch64-lts","linux-radxa"]'
    else
        kernel_choices='["linux","linux-zen","linux-lts","linux-hardened"]'
    fi

    local cats_json
    cats_json=$(cat <<JSONEOF
[
  {"label":"ISO Type","items":[
    {"id":"ISO_BOOT_MODE","label":"Boot mode","value":"$(state_get ISO_BOOT_MODE live)","widget":"menu","choices":["live","installer"]}
  ]},
  {"label":"Architecture","items":[
    {"id":"TARGET_ARCH","label":"Target Architecture","value":"$(state_get TARGET_ARCH x86_64)","widget":"menu","choices":["x86_64","aarch64"]},
    {"id":"BOARD_NAME","label":"Board","value":"$(state_get BOARD_NAME '')","widget":"menu","choices":["Raspberry Pi 4","Raspberry Pi 3B+","Odroid N2","Pinephone","Firefly RK3399","Orange Pi PC2","QEMU VM"],"visible_if":{"TARGET_ARCH":"aarch64"}}
  ]},
  {"label":"Live Environment","items":[
    {"id":"WM_DE","label":"Desktop","value":"$(state_get WM_DE none)","widget":"menu","choices":["kde","sonicde","xfce4","lxqt","lxde","hyprland","sway","niri","i3wm","dwm","vxwm","icewm","mango","cinnamon","budgie","moksha","cosmic","none"]},
    {"id":"DISPLAY_MANAGER","label":"Display Manager","value":"$(state_get DISPLAY_MANAGER none)","widget":"menu","choices":["none","lightdm","sddm","soniclogin"]},
    {"id":"X_STACK","label":"Display Stack","value":"$(state_get X_STACK xorg)","widget":"menu","choices":["xlibre","xorg"]},
    {"id":"INIT","label":"Init","value":"$(state_get INIT openrc)","widget":"menu","choices":["openrc","runit","dinit","s6"]},
    {"id":"KERNEL_CHOICE","label":"Kernel","value":"$(state_get KERNEL_CHOICE linux)","widget":"menu","choices":${kernel_choices}},
    {"id":"NETWORK_STACK","label":"Network","value":"$(state_get NETWORK_STACK networkmanager)","widget":"menu","choices":["networkmanager","dhcpcd+iwd","connman","none"]},
    {"id":"AUDIO_STACK","label":"Audio","value":"$(state_get AUDIO_STACK pipewire)","widget":"menu","choices":["pipewire","pulseaudio","none"]}
  ]},
  {"label":"Extras","items":[
    {"id":"ISO_EXTRA_PACKAGES","label":"Extra packages","value":"$(state_get ISO_EXTRA_PACKAGES '')","widget":"checklist","choices":["git","flatpak","fastfetch","firewalld","bluez","zram-tools","fzf","zoxide","starship","eza","btop","htop","nvtop","tmux","neovim","micro","helix","firefox","chromium","qutebrowser","ranger","lf","nnn","thunar","alacritty","kitty","foot","mpv","feh"]}
  ]},
  {"label":"Output","items":[
    {"id":"ISO_OUTPUT_DIR","label":"Output directory","value":"$(state_get ISO_OUTPUT_DIR "${HOME}/ArtixForge-ISO")","widget":"input","placeholder":"${HOME}/ArtixForge-ISO"},
    {"id":"ALLOW_OFFLINE","label":"Offline mode","value":"$(state_get ALLOW_OFFLINE no)","widget":"yesno"}
  ]}
]
JSONEOF
)

    local actions_json='["Load Preset","Save Preset","Build"]'
    local result
    result=$(tui_iso "ISO Builder" "${cats_json}")

    if [[ -z "${result}" ]]; then
        return 1
    fi

    local parsed_type
    parsed_type=$(echo "${result}" | jq -r 'type' 2>/dev/null || echo "string")

    if [[ "${parsed_type}" == "object" ]]; then
        local key val
        while IFS= read -r key; do
            val=$(echo "${result}" | jq -r --arg k "${key}" '.[$k]')
            state_set "${key}" "${val}"
        done <<< "$(echo "${result}" | jq -r 'keys[]')"
        return 0
    fi

    case "${result}" in
        "Save Preset")
            tui_iso_save_preset
            return 1
            ;;
        "Load Preset")
            tui_iso_load_preset
            return 1
            ;;
        *) return 1 ;;
    esac
}

tui_iso_save_preset() {
    local preset_name
    preset_name=$(tui_input "Preset Name" "Enter a name for this ISO preset:" "my-iso") || return 0
    [[ -n "${preset_name}" ]] || return 0

    local preset_dir="${BASE_DIR}/presets"
    mkdir -p "${preset_dir}"
    local preset_file="${preset_dir}/iso-${preset_name// /_}.conf"

    {
        printf "ISO_BOOT_MODE='%s'\n" "$(state_get ISO_BOOT_MODE live)"
        printf "TARGET_ARCH='%s'\n" "$(state_get TARGET_ARCH x86_64)"
        printf "BOARD_NAME='%s'\n" "$(state_get BOARD_NAME '')"
        printf "WM_DE='%s'\n" "$(state_get WM_DE none)"
        printf "DISPLAY_MANAGER='%s'\n" "$(state_get DISPLAY_MANAGER none)"
        printf "X_STACK='%s'\n" "$(state_get X_STACK xorg)"
        printf "INIT='%s'\n" "$(state_get INIT openrc)"
        printf "KERNEL_CHOICE='%s'\n" "$(state_get KERNEL_CHOICE linux)"
        printf "NETWORK_STACK='%s'\n" "$(state_get NETWORK_STACK networkmanager)"
        printf "AUDIO_STACK='%s'\n" "$(state_get AUDIO_STACK pipewire)"
        printf "ISO_EXTRA_PACKAGES='%s'\n" "$(state_get ISO_EXTRA_PACKAGES '')"
        printf "ISO_OUTPUT_DIR='%s'\n" "$(state_get ISO_OUTPUT_DIR '')"
        printf "ALLOW_OFFLINE='%s'\n" "$(state_get ALLOW_OFFLINE no)"
    } > "${preset_file}"

    tui_msg_quick "Preset Saved" "ISO preset '${preset_name}' saved."
}

tui_iso_load_preset() {
    local preset_dir="${BASE_DIR}/presets"
    [[ -d "${preset_dir}" ]] || mkdir -p "${preset_dir}"

    local -a preset_files=()
    while IFS= read -r -d '' preset; do
        local name
        name=$(basename "${preset}" .conf)
        [[ "${name}" == iso-* ]] && preset_files+=("${name#iso-}")
    done < <(find "${preset_dir}" -maxdepth 1 -name 'iso-*.conf' -print0 | sort -z)

    if [[ ${#preset_files[@]} -eq 0 ]]; then
        tui_msg_quick "No Presets" "No saved ISO presets found."
        return 0
    fi

    local chosen
    chosen=$(tui_menu "Load ISO Preset" "Select a saved ISO configuration:" "${preset_files[@]}") || return 0

    local preset_file="${preset_dir}/iso-${chosen}.conf"
    [[ -f "${preset_file}" ]] || { tui_msg_quick "Error" "Preset file not found."; return 1; }

    while IFS='=' read -r key value; do
        [[ -z "${key}" || "${key}" == \#* ]] && continue
        value="${value#\'}"; value="${value%\'}"
        state_set "${key}" "${value}"
    done < "${preset_file}"

    tui_msg_quick "Preset Loaded" "ISO preset '${chosen}' loaded."
}

tui_iso_target_config() {
    tui_collect_install_config
}