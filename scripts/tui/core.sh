#!/usr/bin/env bash
set -Eeuo pipefail

GUM_TITLE_COLOR="${GUM_TITLE_COLOR:-212}"
GUM_ACCENT_COLOR="${GUM_ACCENT_COLOR:-34}"

LOG_FILE="/tmp/artix-installer/install.log"
CHROOT_LOG="/mnt/var/log/artix-installer.log"

FORGE_TUI="${FORGE_TUI:-forge-tui}"

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

_forge() {
    local _dir _tmp _json_out
    _dir=$(mktemp -d --tmpdir forge-tui-XXXXXX)
    chmod 700 "$_dir"
    _tmp="$_dir/input.json"
    printf '%s\n' "$1" > "$_tmp"
    _json_out=$("$FORGE_TUI" --mode widget --input "$_tmp" 2>/dev/null)
    rm -rf "$_dir"
    printf '%s\n' "$_json_out"
}

_forge_result() {
    local _json
    _json=$(_forge "$1")
    jq -r '.result // .selected // empty' <<< "$_json"
}

_forge_cancelled() {
    local _json
    _json=$(_forge "$1")
    [[ "$(jq -r '.cancelled' <<< "$_json")" == "true" ]]
}

tui_msg() {
    local title="${1}" msg="${2}"
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}"
    printf '%s\n' "${msg}"
    _forge '{"widget":"msg","title":"'"${title//\"/\\\"}"'","message":"'"${msg//\"/\\\"}"'"}' >/dev/null
}

tui_yesno() {
    local title="${1}" msg="${2}"
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}"
    printf '%s\n' "${msg}"
    local result
    result=$(_forge_result '{"widget":"yesno","title":"'"${title//\"/\\\"}"'","message":"'"${msg//\"/\\\"}"'"}')
    [[ "$result" == "true" ]] && return 0 || return 1
}

tui_input() {
    local title="${1}" msg="${2}" default="${3:-}"
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    [[ -n "${msg}" ]] && printf '%s\n' "${msg}" >&2
    _forge_result '{"widget":"input","title":"'"${title//\"/\\\"}"'","message":"'"${msg//\"/\\\"}"'","default":"'"${default//\"/\\\"}"'"}'
}

tui_password() {
    local title="${1}" msg="${2}"
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    [[ -n "${msg}" ]] && printf '%s\n' "${msg}" >&2
    _forge_result '{"widget":"password","title":"'"${title//\"/\\\"}"'","message":"'"${msg//\"/\\\"}"'"}'
}

tui_msg_quick() {
    local title="${1}" msg="${2}"
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}"
    printf '%s\n' "${msg}"
}

tui_password_confirm() {
    local title="${1:-Password}" prompt="${2:-Enter password:}" confirm_prompt="${3:-Confirm password:}"
    local pass confirm
    while true; do
        printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
        pass=$(_forge_result '{"widget":"password","title":"'"${title//\"/\\\"}"'","message":"'"${prompt//\"/\\\"}"'"}')
        [[ -n "${pass}" ]] || return 1
        confirm=$(_forge_result '{"widget":"password","title":"'"${title//\"/\\\"}"'","message":"'"${confirm_prompt//\"/\\\"}"'"}')
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
    local choices_json
    choices_json=$(printf '%s\n' "$@" | jq -R . | jq -s .)
    _forge_result '{"widget":"menu","title":"'"${title//\"/\\\"}"'","message":"'"${msg//\"/\\\"}"'","choices":'"${choices_json}"'}'
}

tui_menu_custom() {
    local title="${1}" msg="${2}" height="${3:-15}"
    shift 3
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    [[ -n "${msg}" ]] && printf '%s\n' "${msg}" >&2
    local choices_json
    choices_json=$(printf '%s\n' "$@" | jq -R . | jq -s .)
    _forge_result '{"widget":"menu","title":"'"${title//\"/\\\"}"'","message":"'"${msg//\"/\\\"}"'","choices":'"${choices_json}"',"height":'"${height}"'}'
}

tui_checklist() {
    local title="${1}" msg="${2}"
    shift 2
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    [[ -n "${msg}" ]] && printf '%s\n' "${msg}" >&2
    local choices_json result
    choices_json=$(printf '%s\n' "$@" | jq -R . | jq -s .)
    result=$(_forge_result '{"widget":"checklist","title":"'"${title//\"/\\\"}"'","message":"'"${msg//\"/\\\"}"'","choices":'"${choices_json}"'}')
    printf '%s\n' "${result}"
}

tui_filter() {
    local title="${1}" msg="${2}"
    shift 2
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    [[ -n "${msg}" ]] && printf '%s\n' "${msg}" >&2
    local choices_json
    choices_json=$(printf '%s\n' "$@" | jq -R . | jq -s .)
    _forge_result '{"widget":"filter","title":"'"${title//\"/\\\"}"'","message":"'"${msg//\"/\\\"}"'","choices":'"${choices_json}"'}'
}

tui_radiolist() { tui_menu "$@"; }

tui_spin() {
    local title="${1}" cmd="${2}"
    bash -c "${cmd}" 2>&1 | while IFS= read -r line; do log_info "${line}"; done
}

tui_show_file() {
    local title="${1}" file="${2}"
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}"
    _forge '{"widget":"summary","title":"'"${title//\"/\\\"}"'","file":"'"${file}"'"}' >/dev/null
}