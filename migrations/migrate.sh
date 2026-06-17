#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${DEBUG:-false}" == "true" || "${ARTIX_DEBUG:-false}" == "true" ]]; then
    exec 19> "${BASE_DIR}/artix-migration-debug.log"
    export BASH_XTRACEFD=19
    export PS4='+ ${BASH_SOURCE}:${LINENO}:${FUNCNAME[0]}: '
    set -x
fi

MIGRATIONS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

tui_migration_menu() {
    local choice
    choice=$(tui_menu "System Migration" "What would you like to migrate?" \
        "Init System – convert OpenRC ↔ runit ↔ dinit ↔ s6" \
        "Desktop Environment – swap KDE ↔ XFCE ↔ Sway etc." \
        "Abort") || return 1

    case "${choice}" in
        "Init System"*)
            if [[ -f "${MIGRATIONS_DIR}/inits/common.sh" ]]; then
                source "${MIGRATIONS_DIR}/inits/common.sh"
                tui_init_migration_menu
            else
                tui_msg_quick "Not Available" "Init migration module not found."
            fi
            ;;
        "Desktop Environment"*)
            if [[ -f "${MIGRATIONS_DIR}/des/common.sh" ]]; then
                source "${MIGRATIONS_DIR}/des/common.sh"
                tui_de_migration_menu
            else
                tui_msg_quick "Not Available" "Desktop migration module not found."
            fi
            ;;
        *) return 0 ;;
    esac
}