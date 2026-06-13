#!/usr/bin/env bash
set -Eeuo pipefail

tui_select_desktop() {
    local d
    d=$(tui_menu "Desktop Environment" "Select desktop:" \
        "xfce4" "lxqt" "kde" "lxde" "mango" "hyprland" "niri" "sway" \
        "i3wm" "dwm" "vxwm" "icewm" "sonicde" "none") || return 1
    state_set WM_DE "${d}"

    if [[ "${d}" == "kde" ]]; then
        local profile
        profile=$(tui_menu "KDE Profile" "Select KDE Plasma profile:" \
            "minimal" "desktop" "full") || return 1
        state_set KDE_PROFILE "${profile}"
    else
        state_set KDE_PROFILE "none"
    fi

    if [[ "${d}" == "sonicde" ]]; then
        tui_msg_quick "SonicDE Warning" \
            "SonicDE is a third-party KDE replacement.\n\n" \
            "!!! Their package signing key infrastructure is incomplete.\n" \
            "SonicDE will be installed with signature verification DISABLED\n" \
            "(SigLevel = Never) because the required key 70B4B1EF0FF2A94E\n" \
            "is not published by the SonicDE project.\n\n" \
            "I discovered this very recently.\n\n" \
            "Shoutout to Joseph (smokexjc) for reminding me about\n" \
            "rule #1 after I called his community member a parrot\n" \
            "for telling me to 'check the documentation' —\n" \
            "which I had already read multiple times."
        if ! tui_yesno "Continue with SonicDE?" "Install SonicDE with signature verification disabled?"; then
            tui_select_desktop
            return 0
        fi
    fi
}

tui_select_display_manager() {
    local wm dm
    wm="$(state_get WM_DE none)"
    if [[ "${wm}" =~ ^(none|dwm|i3wm|icewm|hyprland|mango|niri|sway)$ ]]; then
        dm=$(tui_menu "Display Manager" "Select display manager:" "None" "LightDM" "SDDM") || return 1
    else
        dm=$(tui_menu "Display Manager" "Select display manager:" "LightDM" "SDDM") || return 1
    fi
    state_set DISPLAY_MANAGER "${dm,,}"
}

tui_select_xstack() {
    local wm stack
    wm="$(state_get WM_DE none)"
    if [[ "${wm}" == "none" ]]; then
        state_set X_STACK "none"
        return 0
    fi
    stack=$(tui_menu "Display Stack" "Select display stack:" "X.Org" "xLibre") || return 1
    state_set X_STACK "${stack,,}"
}