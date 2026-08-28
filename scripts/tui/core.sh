#!/usr/bin/env bash
set -Eeuo pipefail

GUM_TITLE_COLOR="${GUM_TITLE_COLOR:-212}"
GUM_ACCENT_COLOR="${GUM_ACCENT_COLOR:-34}"

LOG_FILE="/tmp/artix-installer/install.log"
CHROOT_LOG="/mnt/var/log/artix-installer.log"

FILLY_DAEMON_SOCKET="/tmp/filly.sock"
FILLY_DAEMON_PID=""
FILLY_DAEMON_LOG="/tmp/artix-installer/filly-daemon.log"

_ensure_log_dirs() {
    mkdir -p "$(dirname "${LOG_FILE}")"
    [[ -d /mnt ]] && mkdir -p "$(dirname "${CHROOT_LOG}")" 2>/dev/null || true
    mkdir -p "$(dirname "${FILLY_DAEMON_LOG}")"
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
    if [[ -n "${FILLY_DAEMON_PID}" ]] && kill -0 "${FILLY_DAEMON_PID}" 2>/dev/null && [[ -S "${FILLY_DAEMON_SOCKET}" ]]; then
        return 0
    fi
    if [[ -S "${FILLY_DAEMON_SOCKET}" ]]; then rm -f "${FILLY_DAEMON_SOCKET}"; fi
    _ensure_log_dirs
    "${FILLY_BIN:-filly}" daemon --socket "${FILLY_DAEMON_SOCKET}" \
        </dev/null &>"${FILLY_DAEMON_LOG}" &
    FILLY_DAEMON_PID=$!
    for _ in {1..100}; do
        if [[ -S "${FILLY_DAEMON_SOCKET}" ]]; then
            sleep 0.1
            export FILLY_SOCKET="${FILLY_DAEMON_SOCKET}"
            return 0
        fi
        sleep 0.05
    done
    log_error "FILLY daemon failed to start"
    return 1
}

_stop_filly_daemon() {
    if [[ -n "${FILLY_DAEMON_PID}" ]] && kill -0 "${FILLY_DAEMON_PID}" 2>/dev/null; then
        kill "${FILLY_DAEMON_PID}" 2>/dev/null || true
        wait "${FILLY_DAEMON_PID}" 2>/dev/null || true
    fi
    rm -f "${FILLY_DAEMON_SOCKET}"
    unset FILLY_SOCKET FILLY_DAEMON_PID
    stty sane 2>/dev/null || true
}

trap '_stop_filly_daemon' EXIT

_filly_relay() {
    local json="${1}"
    "${FILLY_BIN:-filly}" relay --socket "${FILLY_SOCKET}" "${json}" 2>/dev/null
}

tui_msg() {
    local title="${1}" message="${2}"
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    [[ -n "${message}" ]] && printf '%s\n' "${message}" >&2
    _start_filly_daemon || return 1
    "${FILLY_BIN:-filly}" relay --socket "${FILLY_SOCKET}" \
        "{\"widget\":\"msg\",\"params\":{\"title\":\"${title}\",\"message\":\"${message}\"}}" >/dev/null 2>&1
}

tui_yesno() {
    local title="${1}" message="${2}"
    _start_filly_daemon || return 1
    local result
    result=$(_filly_relay "{\"widget\":\"yesno\",\"params\":{\"title\":\"${title}\",\"message\":\"${message}\",\"default\":true}}")
    [[ "${result}" == "true" ]]
}

tui_input() {
    local title="${1}" message="${2}" default="${3:-}"
    _start_filly_daemon || return 1
    _filly_relay "{\"widget\":\"input\",\"params\":{\"title\":\"${title}\",\"message\":\"${message}\",\"default\":\"${default}\"}}"
}

tui_password() {
    local title="${1}" message="${2}"
    _start_filly_daemon || return 1
    _filly_relay "{\"widget\":\"password\",\"params\":{\"title\":\"${title}\",\"message\":\"${message}\"}}"
}

tui_menu() {
    local title="${1}" message="${2}"
    shift 2
    _start_filly_daemon || return 1
    local choices_json
    choices_json=$(printf '%s\n' "$@" | jq -R . | jq -s -c .)
    _filly_relay "{\"widget\":\"menu\",\"params\":{\"title\":\"${title}\",\"message\":\"${message}\",\"choices\":${choices_json}}}"
}

tui_checklist() {
    local title="${1}" message="${2}"
    shift 2
    _start_filly_daemon || return 1
    local choices_json
    choices_json=$(printf '%s\n' "$@" | jq -R . | jq -s -c .)
    _filly_relay "{\"widget\":\"checklist\",\"params\":{\"title\":\"${title}\",\"message\":\"${message}\",\"choices\":${choices_json}}}"
}

tui_filter() {
    local title="${1}" message="${2}"
    shift 2
    _start_filly_daemon || return 1
    local choices_json
    choices_json=$(printf '%s\n' "$@" | jq -R . | jq -s -c .)
    _filly_relay "{\"widget\":\"filter\",\"params\":{\"title\":\"${title}\",\"message\":\"${message}\",\"choices\":${choices_json}}}"
}

tui_multiselect() {
    local title="${1}" message="${2}"
    shift 2
    _start_filly_daemon || return 1
    local choices_json
    choices_json=$(printf '%s\n' "$@" | jq -R . | jq -s -c .)
    _filly_relay "{\"widget\":\"multiselect\",\"params\":{\"title\":\"${title}\",\"message\":\"${message}\",\"choices\":${choices_json}}}"
}

tui_file_picker() {
    local title="${1}" start_dir="${2:-/}" filter="${3:-}"
    _start_filly_daemon || return 1
    _filly_relay "{\"widget\":\"file_picker\",\"params\":{\"title\":\"${title}\",\"start_dir\":\"${start_dir}\",\"filter_ext\":\"${filter}\"}}"
}

tui_summary() {
    local title="${1}" file="${2:-}" message="${3:-}"
    local content=""
    if [[ -n "${file}" && -f "${file}" ]]; then
        content=$(<"${file}")
    else
        content="${message}"
    fi
    _start_filly_daemon || return 1
    "${FILLY_BIN:-filly}" relay --socket "${FILLY_SOCKET}" \
        "{\"widget\":\"summary\",\"params\":{\"title\":\"${title}\",\"message\":\"${content}\"}}" >/dev/null 2>&1
}

tui_edit() {
    local title="${1}" file="${2}"
    local content=""
    [[ -f "${file}" ]] && content=$(<"${file}")
    _start_filly_daemon || return 1
    local result
    result=$(_filly_relay "{\"widget\":\"text_editor\",\"params\":{\"title\":\"${title}\",\"file_path\":\"${file}\",\"content\":\"${content}\"}}")
    [[ -n "${result}" ]] && printf '%s\n' "${result}" > "${file}"
}

tui_disk() {
    local title="${1}" disk="${2}" partitions_json="${3:-[]}" free_space_json="${4:-[]}" readonly="${5:-false}"
    _start_filly_daemon || return 1
    _filly_relay "{\"widget\":\"disk\",\"params\":{\"title\":\"${title}\",\"disk\":\"${disk}\",\"partitions\":${partitions_json},\"free_space\":${free_space_json},\"readonly\":${readonly}}}"
}

tui_msg_quick() {
    local title="${1}" msg="${2}"
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    printf '%s\n' "${msg}" >&2
}

tui_password_confirm() {
    local title="${1:-Password}" prompt="${2:-Enter password:}" confirm_prompt="${3:-Confirm password:}"
    local pass confirm
    while true; do
        pass=$(tui_password "${title}" "${prompt}")
        [[ -n "${pass}" ]] || return 1
        confirm=$(tui_password "${title}" "${confirm_prompt}")
        [[ -n "${confirm}" ]] || return 1
        if [[ "${pass}" == "${confirm}" ]]; then
            printf '%s\n' "${pass}"
            return 0
        fi
        tui_msg_quick "Mismatch" "Passwords do not match. Try again."
    done
}

tui_hub() {
    local title="${1}" categories_json="${2}" actions_json="${3}"
    _start_filly_daemon || return 1
    local request
    request=$(jq -cn --arg title "${title}" --argjson cats "${categories_json}" --argjson acts "${actions_json}" \
        '{widget:"hub",params:{title:$title,categories:$cats,actions:$acts},relay:true}')
    _filly_relay "${request}"
}

tui_install_hub() {
    local title="${1}" categories_json="${2}" actions_json="${3}" boot_mode="${4:-uefi}"
    _start_filly_daemon || return 1
    local request
    request=$(jq -cn --arg title "${title}" --argjson cats "${categories_json}" --argjson acts "${actions_json}" --arg boot "${boot_mode}" \
        '{widget:"install_hub",params:{title:$title,categories:$cats,actions:$acts,boot_mode:$boot},relay:true}')
    _filly_relay "${request}"
}

tui_recovery() {
    local title="${1}" status_json="${2}" repairs_json="${3}"
    _start_filly_daemon || return 1
    _filly_relay "{\"widget\":\"recovery\",\"params\":{\"title\":\"${title}\",\"status\":${status_json},\"repairs\":${repairs_json}}}"
}

tui_iso() {
    local title="${1}" categories_json="${2}"
    _start_filly_daemon || return 1
    _filly_relay "{\"widget\":\"iso\",\"params\":{\"title\":\"${title}\",\"categories\":${categories_json}}}"
}

tui_migration_init() {
    local title="${1}" current_init="${2}"
    _start_filly_daemon || return 1
    _filly_relay "{\"widget\":\"migration_init\",\"params\":{\"title\":\"${title}\",\"current_init\":\"${current_init}\"}}"
}

tui_migration_desktop() {
    local title="${1}" current_de="${2}"
    _start_filly_daemon || return 1
    _filly_relay "{\"widget\":\"migration_desktop\",\"params\":{\"title\":\"${title}\",\"current_de\":\"${current_de}\"}}"
}

tui_poweruser() {
    local title="${1}" categories_json="${2}"
    _start_filly_daemon || return 1
    _filly_relay "{\"widget\":\"poweruser\",\"params\":{\"title\":\"${title}\",\"categories\":${categories_json}}}"
}