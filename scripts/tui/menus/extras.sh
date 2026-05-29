#!/usr/bin/env bash
set -Eeuo pipefail

tui_select_extras() {
    local extras category

    category=$(tui_menu "Extras" "Select category:" \
        "System Tools" \
        "Editors" \
        "Browsers" \
        "File Managers" \
        "Terminals" \
        "Shell & Prompt" \
        "Monitoring" \
        "Media" \
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
            "Done (finish selection)") || break
    done

    state_set EXTRAS "${selected//$'\n'/ }"
}