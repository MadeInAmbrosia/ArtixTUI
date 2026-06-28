#!/usr/bin/env bash
set -Eeuo pipefail

# SAFETY FILTER!!!
readonly EXTRAS_SAFETY_FILTER='linux-.*|systemd.*|plasma.*|grub|mkinitcpio|.*-openrc|.*-runit|.*-dinit|.*-s6|sddm|lightdm|gdm|xorg-.*|xlibre-.*|wayland|hyprland|sway|niri|pipewire|pulseaudio|networkmanager|connman|dhcpcd|efibootmgr|filesystem|pacman|bash|coreutils|util-linux'

declare -A WAYLAND_TOOLS=(
    ["mango"]="swaybg swaylock waybar wofi foot"
    ["hyprland"]="hyprpaper hyprlock waybar wofi foot"
    ["sway"]="swaybg swaylock waybar wofi foot"
    ["niri"]="swaybg swaylock waybar fuzzel foot"
    ["cosmic"]=""
)

_wayland_extras_for() {
    local wm="${1}"
    printf '%s' "${WAYLAND_TOOLS[$wm]:-swaybg swaylock waybar wofi foot}"
}

tui_search_extras() {
    log_info "Building safe package index..."

    local full_list
    full_list=$(pacman -Sl {world,galaxy} 2>/dev/null \
        | awk '{print $2}' \
        | grep -vE "${EXTRAS_SAFETY_FILTER}" \
        | sort -u)

    if [[ -z "${full_list}" ]]; then
        tui_msg_quick "Error" "Could not load package list from pacman."
        return 1
    fi

    local selected
    selected=$(printf '%s\n' "${full_list}" \
        | tui_filter "Package Search" "Type to search packages (Tab to mark, Enter to confirm)" \
            --no-limit --placeholder "e.g. firefox, cmatrix, neovim...") || return 1

    if [[ -n "${selected}" ]]; then
        local count
        count=$(echo "${selected}" | wc -l)
        log_info "User selected ${count} package(s) from search"
        printf '%s\n' "${selected}"
        return 0
    fi
    return 1
}

tui_select_extras() {
    local wm_de extras category
    wm_de="$(state_get WM_DE none)"

    case "${wm_de}" in
        mango)
            tui_msg_quick "MangoWM" "MangoWM is a minimal compositor.\nYou'll want a wallpaper, launcher, and status bar."
            ;;
        hyprland)
            tui_msg_quick "Hyprland Setup" "Hyprland needs hyprpaper, hyprlock, waybar, and wofi for a full desktop."
            ;;
        sway|niri)
            tui_msg_quick "Wayland Setup" "${wm_de} needs swaybg, swaylock, waybar, and a launcher for a full desktop."
            ;;
    esac

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
        "Search for packages..." \
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
                local tools
                tools=$(_wayland_extras_for "${wm_de}")
                if [[ -n "${tools}" ]]; then
                    tui_msg_quick "Wayland Extras" "Recommended for ${wm_de}: ${tools}"
                fi
                local wayland_items=(
                    "swaybg"    "wallpaper daemon (wlroots)"
                    "swaylock"  "screen locker (wlroots)"
                    "hyprpaper" "wallpaper daemon (Hyprland)"
                    "hyprlock"  "screen locker (Hyprland)"
                    "waybar"    "status bar (wlroots/Hyprland)"
                    "wofi"      "application launcher (wlroots)"
                    "fuzzel"    "application launcher (wlroots)"
                    "foot"      "terminal emulator (Wayland-native)"
                )
                local wayland_checklist=()
                for ((i=0; i<${#wayland_items[@]}; i+=2)); do
                    wayland_checklist+=("${wayland_items[i]}")
                done
                selected+=$(tui_checklist "Wayland Extras" "Select Wayland tools:" "${wayland_checklist[@]}") || true
                ;;
            "Search for packages..."*)
                local search_result
                search_result=$(tui_search_extras) || true
                if [[ -n "${search_result}" ]]; then
                    selected+="${search_result}"$'\n'
                    local count
                    count=$(echo "${search_result}" | wc -l)
                    tui_msg_quick "Added" "${count} package(s) added."
                fi
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
            "Search for packages..." \
            "Done (finish selection)") || break
    done

    state_set EXTRAS "${selected//$'\n'/ }"
}