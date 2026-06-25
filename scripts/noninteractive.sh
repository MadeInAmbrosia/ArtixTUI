#!/usr/bin/env bash
set -Eeuo pipefail

tui_msg() { return 0; }

tui_yesno() {
    local title="$1"
    case "${title}" in
        "Mirror Ranking")   return 1 ;;
        "Secure Boot")      [[ "$(state_get SIGN_UKI no)" == "yes" ]] && return 0 || return 1 ;;
        *)                  return 0 ;;
    esac
}

tui_input() { printf '%s' "${3:-}"; return 0; }

tui_password() {
    local title="$1"
    case "${title}" in
        *"LUKS"*)   state_get LUKS_PASS "" ;;
        *)          printf '' ;;
    esac
    return 0
}

tui_msg_quick() { return 0; }

tui_password_confirm() {
    local title="${1:-Password}"
    case "${title}" in
        *"User Password"*)      state_get USER_PASS "" ;;
        *"Root Password"*)      state_get ROOT_PASS "" ;;
        *"LUKS"*)               state_get LUKS_PASS "" ;;
        *"ZFS"*)                state_get ZFS_PASSPHRASE "" ;;
        *)                      printf '' ;;
    esac
    return 0
}

tui_menu() { printf '%s' "${1:-}"; return 0; }
tui_checklist() { return 0; }
tui_spin() { bash -c "$2"; }
tui_show_file() { return 0; }