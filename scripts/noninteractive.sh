#!/usr/bin/env bash
set -Eeuo pipefail

# Override all tui_* functions to return defaults (no user interaction)
tui_msg() { return 0; }
tui_yesno() {
    local title="$1" msg="$2"
    case "${title}" in
        "Secure Boot")
            [[ "$(state_get SIGN_UKI no)" == "yes" ]]
            return $?
            ;;
        *)
            return 0  # default to Yes
            ;;
    esac
}
tui_input() { printf '%s' "${3:-}"; return 0; }
tui_password() { printf ''; return 0; }
tui_msg_quick() { return 0; }
tui_password_confirm() { printf '%s' "${1:-}"; return 0; }
tui_menu() { printf '%s' "${1}"; return 0; }
tui_checklist() { return 0; }
tui_spin() {
    bash -c "$2"
}
tui_show_file() { return 0; }