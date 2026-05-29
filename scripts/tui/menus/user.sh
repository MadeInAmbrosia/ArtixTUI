#!/usr/bin/env bash
set -Eeuo pipefail

tui_select_username() {
    local u
    u=$(tui_input "Username" "Enter username:" "artix") || return 1
    u="${u//[$'\r'$'\n'$'\t' ]/}"
    [[ -n "${u}" ]] || return 1
    state_set USER_NAME "${u}"
}

tui_select_user_password() {
    local pass
    pass=$(tui_password_confirm "User Password" "Enter user password:" "Confirm password:") || return 1
    state_set USER_PASS "${pass}"
}

tui_select_root_password() {
    local pass
    pass=$(tui_password_confirm "Root Password" "Enter root password:" "Confirm password:") || return 1
    state_set ROOT_PASS "${pass}"
}

tui_select_hostname() {
    local h
    while true; do
        h=$(tui_input "Hostname" "Enter system hostname:" "artix") || return 1
        h="${h//[$'\r'$'\n'$'\t' ]/}"
        [[ -n "${h}" ]] || return 1
        if [[ "${h}" =~ ^[a-zA-Z0-9][a-zA-Z0-9\-]*$ ]]; then
            state_set HOSTNAME "${h}"
            return 0
        fi
        tui_msg_quick "Invalid Hostname" "Allowed: a-z, A-Z, 0-9, dash. Start with letter/digit."
    done
}

tui_select_timezone() {
    local tz
    while true; do
        tz=$(tui_input "Timezone" "Enter timezone (Region/City):" "Europe/Belgrade") || return 1
        if [[ -f "/usr/share/zoneinfo/${tz}" ]]; then break; fi
        tui_msg_quick "Invalid Timezone" "Timezone not found. Example: Europe/London"
    done
    state_set TIMEZONE "${tz}"
}

tui_select_locale() {
    local l
    l=$(tui_input "Locale" "Enter locale:" "en_US.UTF-8") || return 1
    state_set LOCALE "${l}"
}

tui_select_priv_escalation() {
    local priv
    priv=$(tui_menu "Privilege Escalation" "Select privilege escalation tool:" \
        "sudo" "doas") || return 1
    state_set PRIV_ESCALATION "${priv,,}"
}

tui_select_keyboard_layout() {
    local k
    k=$(tui_input "Keyboard Layout" "Enter keyboard layout:" "us") || return 1
    state_set KEYMAP "${k}"
}

tui_select_shell() {
    local s
    s=$(tui_menu "User Shell" "Select default shell:" "bash" "zsh" "fish") || return 1
    state_set USER_SHELL "${s}"
}

tui_select_microcode() {
    local detected='amd-ucode'
    grep -q 'GenuineIntel' /proc/cpuinfo && detected='intel-ucode'

    if tui_yesno "CPU Microcode" "Detected ${detected}. Use automatically?"; then
        state_set MICROCODE_OVERRIDE "${detected}"
        return 0
    fi
    local u
    u=$(tui_menu "CPU Microcode" "Select microcode:" "amd-ucode" "intel-ucode" "none") || return 1
    state_set MICROCODE_OVERRIDE "${u}"
}