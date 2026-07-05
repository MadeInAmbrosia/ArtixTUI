#!/usr/bin/env bash
set -Eeuo pipefail

ISO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

tui_iso_hub() {
    local cats_json
    cats_json=$(cat <<JSONEOF
[
  {"label":"ISO Type","items":[
    {"id":"ISO_BOOT_MODE","label":"Boot mode","value":"$(state_get ISO_BOOT_MODE live)","widget":"menu","choices":["live","installer"]}
  ]},
  {"label":"Live Environment","items":[
    {"id":"WM_DE","label":"Desktop","value":"$(state_get WM_DE none)","widget":"menu","choices":["kde","sonicde","xfce4","lxqt","lxde","hyprland","sway","niri","i3wm","dwm","vxwm","icewm","mango","cinnamon","budgie","moksha","cosmic","none"]},
    {"id":"DISPLAY_MANAGER","label":"Display Manager","value":"$(state_get DISPLAY_MANAGER none)","widget":"menu","choices":["none","lightdm","sddm","soniclogin"]},
    {"id":"X_STACK","label":"Display Stack","value":"$(state_get X_STACK xorg)","widget":"menu","choices":["xlibre","xorg"]},
    {"id":"INIT","label":"Init","value":"$(state_get INIT openrc)","widget":"menu","choices":["openrc","runit","dinit","s6"]},
    {"id":"KERNEL_CHOICE","label":"Kernel","value":"$(state_get KERNEL_CHOICE linux)","widget":"menu","choices":["linux","linux-zen","linux-lts","linux-hardened"]},
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

    local result
    result=$(tui_iso "ISO Builder" "${cats_json}")

    if [[ -z "${result}" ]]; then
        return 1
    fi

    local key val
    while IFS= read -r key; do
        val=$(echo "${result}" | jq -r --arg k "${key}" '.[$k]')
        state_set "${key}" "${val}"
    done <<< "$(echo "${result}" | jq -r 'keys[]')"

    return 0
}

tui_iso_target_config() {
    # Reuse the installer hub for target system config when offline mode is enabled
    tui_collect_install_config
}