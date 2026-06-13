#!/usr/bin/env bash
set -Eeuo pipefail

tui_select_extras() {
    local wm_de extras category
    wm_de="$(state_get WM_DE none)"

    case "${wm_de}" in
        mango)
            tui_msg_quick "MangoWM" "MangoWM is a minimal compositor.\nYou'll want a wallpaper, launcher, and status bar."
            ;;
        hyprland|sway|niri)
            tui_msg_quick "Wayland Setup" "${wm_de} needs a few extras for a full desktop.\nConsider a wallpaper, launcher, and bar."
            ;;
    esac

    local -A wayland_defaults=(
        ["mango"]="swaybg wofi waybar"
        ["hyprland"]="waybar wofi hyprpaper"
        ["sway"]="swaybg waybar wofi"
        ["niri"]="swaybg waybar wofi"
    )

    category=$(tui_menu "Extras" "Select category:" \
        "System Tools" \
        "Editors" \
        "Browsers" \
        "File Managers" \
        "Terminals" \
        "Shell & Prompt" \
        "Monitoring" \
        "Media" \
        "Wayland Extras" \
        "Done (finish selection)") || return 1

    local selected=""
    while [[ "${category}" != "Done"* ]]; do
        case "${category}" in
            "System Tools")
                selected+=$(tui_checklist "System Tools" "Select system packages:" \
                    "git" "flatpak" "firewalld" "bluez" "zram-tools" "usb_modeswitch") || true
                ;;
            "Editors")
                selected+=$(tui_checklist "Editors" "Select text editors:" \
                    "nano" "vim" "neovim" "micro" "helix") || true
                ;;
            "Browsers")
                selected+=$(tui_checklist "Browsers" "Select web browsers:" \
                    "firefox" "chromium" "qutebrowser") || true
                ;;
            "File Managers")
                selected+=$(tui_checklist "File Managers" "Select file managers:" \
                    "ranger" "lf" "nnn" "thunar") || true
                ;;
            "Terminals")
                selected+=$(tui_checklist "Terminals" "Select terminal emulators:" \
                    "alacritty" "kitty" "foot") || true
                ;;
            "Shell & Prompt")
                selected+=$(tui_checklist "Shell & Prompt" "Select shell tools:" \
                    "fastfetch" "fzf" "zoxide" "starship" "eza" "tmux") || true
                ;;
            "Monitoring")
                selected+=$(tui_checklist "Monitoring" "Select monitoring tools:" \
                    "btop" "htop" "nvtop") || true
                ;;
            "Media")
                selected+=$(tui_checklist "Media" "Select media tools:" \
                    "mpv" "feh") || true
                ;;
            "Wayland Extras")
                local wayland_items=(
                    "swaybg" "wallpaper daemon for wlroots compositors"
                    "swaylock" "screen locker"
                    "waybar" "status bar"
                    "wofi" "application launcher"
                    "fuzzel" "application launcher"
                    "foot" "terminal emulator"
                    "hyprpaper" "wallpaper daemon for Hyprland"
                )
                local wayland_checklist=()
                for ((i=0; i<${#wayland_items[@]}; i+=2)); do
                    wayland_checklist+=("${wayland_items[i]}")
                done
                selected+=$(tui_checklist "Wayland Extras" "Select Wayland tools:" "${wayland_checklist[@]}") || true
                ;;
        esac
        selected+=$'\n'
        category=$(tui_menu "Extras" "Select category:" \
            "System Tools" \
            "Editors" \
            "Browsers" \
            "File Managers" \
            "Terminals" \
            "Shell & Prompt" \
            "Monitoring" \
            "Media" \
            "Wayland Extras" \
            "Done (finish selection)") || break
    done

    state_set EXTRAS "${selected//$'\n'/ }"
}