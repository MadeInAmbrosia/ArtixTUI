#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${FILLY_BACKEND:-tui}" == "gui" ]]; then
    source "${BASE_DIR}/FILLY/filly_graphical.sh"
else
    source "${BASE_DIR}/FILLY/fil.sh"
fi

GUM_TITLE_COLOR="${GUM_TITLE_COLOR:-212}"
GUM_ACCENT_COLOR="${GUM_ACCENT_COLOR:-34}"

LOG_FILE="/tmp/artix-installer/install.log"
CHROOT_LOG="/mnt/var/log/artix-installer.log"

FILLY_DAEMON_SOCKET="/tmp/filly.sock"
FILLY_DAEMON_PID=""

_ensure_log_dirs() {
    mkdir -p "$(dirname "${LOG_FILE}")"
    [[ -d /mnt ]] && mkdir -p "$(dirname "${CHROOT_LOG}")" 2>/dev/null || true
}

theme_ansi_code() { printf '38;5;%s' "${1:-212}"; }
theme_ansi()      { printf '\e[%sm' "$(theme_ansi_code "${1:-212}")"; }

log_info() {
    local msg="${1}" colour
    colour=$(theme_ansi "${GUM_ACCENT_COLOR:-34}")
    _ensure_log_dirs
    printf '%s[*] %s\e[0m\n' "${colour}" "${msg}" | tee -a "${LOG_FILE}" >&2
    [[ -d /mnt ]] && printf '[*] %s\n' "${msg}" >> "${CHROOT_LOG}" 2>/dev/null || true
}

log_warn() {
    local msg="${1}" colour
    colour=$(theme_ansi "${GUM_TITLE_COLOR:-212}")
    _ensure_log_dirs
    printf '%s[!] %s\e[0m\n' "${colour}" "${msg}" | tee -a "${LOG_FILE}" >&2
    [[ -d /mnt ]] && printf '[!] %s\n' "${msg}" >> "${CHROOT_LOG}" 2>/dev/null || true
}

log_error() {
    local msg="${1}"
    _ensure_log_dirs
    printf '\e[1;31m[✗] %s\e[0m\n' "${msg}" | tee -a "${LOG_FILE}" >&2
}

_start_filly_daemon() {
    if [[ "${FILLY_BACKEND:-tui}" == "gui" ]]; then
        return 0
    fi
    if [[ -n "${FILLY_DAEMON_PID}" ]] && kill -0 "${FILLY_DAEMON_PID}" 2>/dev/null; then
        return 0
    fi
    if [[ -S "${FILLY_DAEMON_SOCKET}" ]]; then
        rm -f "${FILLY_DAEMON_SOCKET}"
    fi
    "${FILLY_BIN:-filly}" daemon --socket "${FILLY_DAEMON_SOCKET}" 2>/tmp/filly-daemon.log &
    FILLY_DAEMON_PID=$!
    for _ in {1..50}; do
        [[ -S "${FILLY_DAEMON_SOCKET}" ]] && break
        sleep 0.05
    done
    export FILLY_DAEMON=1
    export FILLY_SOCKET="${FILLY_DAEMON_SOCKET}"
}

_stop_filly_daemon() {
    if [[ -n "${FILLY_DAEMON_PID}" ]] && kill -0 "${FILLY_DAEMON_PID}" 2>/dev/null; then
        if [[ -S "${FILLY_DAEMON_SOCKET}" ]]; then
            printf '{"widget":"quit"}\n' | nc -U "${FILLY_DAEMON_SOCKET}" 2>/dev/null || true
        fi
        kill "${FILLY_DAEMON_PID}" 2>/dev/null || true
        wait "${FILLY_DAEMON_PID}" 2>/dev/null || true
    fi
    rm -f "${FILLY_DAEMON_SOCKET}"
    unset FILLY_DAEMON FILLY_SOCKET FILLY_DAEMON_PID
    stty sane 2>/dev/null || true
}

trap '_stop_filly_daemon' EXIT

tui_msg() {
    local title="${1}" msg="${2}"
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    printf '%s\n' "${msg}" >&2
    if [[ "${FILLY_BACKEND:-tui}" == "gui" ]]; then
        filly_graphical_msg "$@"
    else
        filly_msg "$@"
    fi
}

tui_msg_quick() {
    local title="${1}" msg="${2}"
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    printf '%s\n' "${msg}" >&2
}

tui_yesno() {
    local title="${1}" msg="${2}"
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    printf '%s\n' "${msg}" >&2
    if [[ "${FILLY_BACKEND:-tui}" == "gui" ]]; then
        filly_graphical_yesno "$@"
    else
        filly_yesno "$@"
    fi
}

tui_input() {
    local title="${1}" msg="${2}" default="${3:-}"
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    [[ -n "${msg}" ]] && printf '%s\n' "${msg}" >&2
    if [[ "${FILLY_BACKEND:-tui}" == "gui" ]]; then
        filly_graphical_input "$@"
    else
        filly_input "$@"
    fi
}

tui_password() {
    local title="${1}" msg="${2}"
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    [[ -n "${msg}" ]] && printf '%s\n' "${msg}" >&2
    if [[ "${FILLY_BACKEND:-tui}" == "gui" ]]; then
        filly_graphical_password "$@"
    else
        filly_password "$@"
    fi
}

tui_password_confirm() {
    local title="${1:-Password}" prompt="${2:-Enter password:}" confirm_prompt="${3:-Confirm password:}"
    local pass confirm
    while true; do
        printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
        if [[ "${FILLY_BACKEND:-tui}" == "gui" ]]; then
            pass=$(filly_graphical_password "${title}" "${prompt}")
        else
            pass=$(filly_password "${title}" "${prompt}")
        fi
        [[ -n "${pass}" ]] || return 1
        if [[ "${FILLY_BACKEND:-tui}" == "gui" ]]; then
            confirm=$(filly_graphical_password "${title}" "${confirm_prompt}")
        else
            confirm=$(filly_password "${title}" "${confirm_prompt}")
        fi
        [[ -n "${confirm}" ]] || return 1
        if [[ "${pass}" == "${confirm}" ]]; then
            printf '%s\n' "${pass}"
            return 0
        fi
        tui_msg_quick "Mismatch" "Passwords do not match. Try again."
    done
}

tui_menu() {
    local title="${1}" msg="${2}"
    shift 2
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    [[ -n "${msg}" ]] && printf '%s\n' "${msg}" >&2
    if [[ "${FILLY_BACKEND:-tui}" == "gui" ]]; then
        filly_graphical_menu "${title}" "${msg}" "$@"
    else
        filly_menu "${title}" "${msg}" "$@"
    fi
}

tui_menu_custom() {
    local title="${1}" msg="${2}" height="${3:-15}"
    shift 3
    tui_menu "${title}" "${msg}" "$@"
}

tui_checklist() {
    local title="${1}" msg="${2}"
    shift 2
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    [[ -n "${msg}" ]] && printf '%s\n' "${msg}" >&2
    if [[ "${FILLY_BACKEND:-tui}" == "gui" ]]; then
        filly_graphical_checklist "${title}" "${msg}" "$@"
    else
        filly_checklist "${title}" "${msg}" "$@"
    fi
}

tui_filter() {
    local title="${1}" msg="${2}"
    shift 2
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    [[ -n "${msg}" ]] && printf '%s\n' "${msg}" >&2
    if [[ "${FILLY_BACKEND:-tui}" == "gui" ]]; then
        filly_graphical_filter "${title}" "${msg}" "" "$@"
    else
        filly_filter "${title}" "${msg}" "" "$@"
    fi
}

tui_radiolist() { tui_menu "$@"; }

tui_spin() {
    local title="${1}" cmd="${2}"
    if [[ "${FILLY_BACKEND:-tui}" == "gui" ]]; then
        filly_graphical_progress "${title}" bash -c "${cmd}"
    else
        bash -c "${cmd}" 2>&1 | while IFS= read -r line; do log_info "${line}"; done
    fi
}

tui_show_file() {
    local title="${1}" file="${2}"
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    if [[ "${FILLY_BACKEND:-tui}" == "gui" ]]; then
        filly_graphical_summary "${title}" "${file}"
    else
        filly_summary "${title}" "${file}"
    fi
}

tui_edit() {
    local title="${1}" file="${2}"
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    if [[ "${FILLY_BACKEND:-tui}" == "gui" ]]; then
        filly_graphical_text_editor "${title}" "${file}"
    else
        filly_text_editor "${title}" "${file}"
    fi
}

tui_disk() {
    local title="${1}" disk="${2}" partitions_json="${3:-[]}" free_space_json="${4:-[]}" readonly="${5:-false}"
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    if [[ "${FILLY_BACKEND:-tui}" == "gui" ]]; then
        filly_graphical_disk "${title}" "${disk}" "${partitions_json}" "${free_space_json}" "${readonly}"
    else
        filly_disk "${title}" "${disk}" "${partitions_json}" "${free_space_json}" "${readonly}"
    fi
}

tui_multiselect() {
    local title="${1}" msg="${2}" placeholder="${3:-}" min="${4:-0}" max="${5:-0}"
    shift 5 2>/dev/null || shift 3
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    [[ -n "${msg}" ]] && printf '%s\n' "${msg}" >&2
    if [[ "${FILLY_BACKEND:-tui}" == "gui" ]]; then
        filly_graphical_multiselect "${title}" "${msg}" "$@"
    else
        filly_multiselect "${title}" "${msg}" "$@"
    fi
}

tui_hub() {
    local title="${1}" categories_json="${2}" actions_json="${3}"
    _start_filly_daemon
    if [[ "${FILLY_BACKEND:-tui}" == "gui" ]]; then
        filly_graphical_hub "${title}" "${categories_json}" "${actions_json}"
    else
        filly_hub "${title}" "${categories_json}" "${actions_json}"
    fi
}

tui_install_hub() {
    local title="${1}" categories_json="${2}" actions_json="${3}" boot_mode="${4:-uefi}"
    _start_filly_daemon
    if [[ "${FILLY_BACKEND:-tui}" == "gui" ]]; then
        filly_graphical_install_hub "${title}" "${categories_json}" "${actions_json}" "${boot_mode}"
    else
        filly_install_hub "${title}" "${categories_json}" "${actions_json}" "${boot_mode}"
    fi
}

tui_recovery() {
    local title="${1}" status_json="${2}" repairs_json="${3}"
    _start_filly_daemon
    if [[ "${FILLY_BACKEND:-tui}" == "gui" ]]; then
        filly_graphical_recovery "${title}" "${status_json}" "${repairs_json}"
    else
        filly_recovery "${title}" "${status_json}" "${repairs_json}"
    fi
}

tui_iso() {
    local title="${1}" categories_json="${2}"
    _start_filly_daemon
    if [[ "${FILLY_BACKEND:-tui}" == "gui" ]]; then
        filly_graphical_iso "${title}" "${categories_json}"
    else
        filly_iso "${title}" "${categories_json}"
    fi
}

tui_migration_init() {
    local title="${1}" current_init="${2}"
    _start_filly_daemon
    if [[ "${FILLY_BACKEND:-tui}" == "gui" ]]; then
        filly_graphical_migration_init "${title}" "${current_init}"
    else
        filly_migration_init "${title}" "${current_init}"
    fi
}

tui_migration_desktop() {
    local title="${1}" current_de="${2}"
    _start_filly_daemon
    if [[ "${FILLY_BACKEND:-tui}" == "gui" ]]; then
        filly_graphical_migration_desktop "${title}" "${current_de}"
    else
        filly_migration_desktop "${title}" "${current_de}"
    fi
}

tui_poweruser() {
    local title="${1}" categories_json="${2}"
    _start_filly_daemon
    if [[ "${FILLY_BACKEND:-tui}" == "gui" ]]; then
        filly_graphical_poweruser "${title}" "${categories_json}"
    else
        filly_poweruser "${title}" "${categories_json}"
    fi
}