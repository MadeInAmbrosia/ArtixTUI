#!/usr/bin/env bash
set -Eeuo pipefail

GUM_TITLE_COLOR="${GUM_TITLE_COLOR:-212}"
GUM_ACCENT_COLOR="${GUM_ACCENT_COLOR:-34}"

LOG_FILE="/tmp/artix-installer/install.log"
CHROOT_LOG="/mnt/var/log/artix-installer.log"

FORGE_TUI="${FORGE_TUI:-forge-tui}"
FORGE_TUI_SOCKET="${FORGE_TUI_SOCKET:-/tmp/forge-tui.sock}"
FORGE_TUI_DAEMON="${FORGE_TUI_DAEMON:-}"

[[ -t 1 ]] || FORGE_TUI_DAEMON=""
[[ -n "${FORGE_TUI_DAEMON:-}" ]] && command -v nc &>/dev/null && FORGE_TUI_DAEMON=1 || FORGE_TUI_DAEMON=""

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
    if [[ -n "$FORGE_TUI_DAEMON" ]]; then
        if [[ ! -S "$FORGE_TUI_SOCKET" ]]; then
            "$FORGE_TUI" --daemon --socket "$FORGE_TUI_SOCKET" &
            for _ in {1..50}; do
                [[ -S "$FORGE_TUI_SOCKET" ]] && break
                sleep 0.05
            done
        fi
        printf '%s\n' "$1" | nc -U "$FORGE_TUI_SOCKET" 2>/dev/null
    else
        local _dir _tmp _out
        _dir=$(mktemp -d --tmpdir forge-tui-XXXXXX)
        chmod 700 "$_dir"
        _tmp="$_dir/input.json"
        _out="$_dir/output.json"
        printf '%s\n' "$1" > "$_tmp"
        "$FORGE_TUI" --mode widget --input "$_tmp" --output "$_out" < /dev/tty > /dev/tty 2>/dev/null
        cat "$_out" 2>/dev/null
        rm -rf "$_dir"
    fi
}

_forge_result() {
    local _json _result
    _json=$(_forge "$1")
    
    if [[ -z "${_json}" ]]; then
        log_warn "forge-tui returned empty response"
        return 1
    fi
    
    if [[ "$(jq -r '.cancelled' <<< "$_json" 2>/dev/null)" == "true" ]]; then
        return 1
    fi
    
    _result=$(jq -r 'if .result | type == "array" then .result[] else .result // .selected // empty end' <<< "$_json" 2>/dev/null)
    printf '%s\n' "${_result}"
    return 0
}

_forge_cancelled() {
    local _json
    _json=$(_forge "$1")
    
    if [[ -z "${_json}" ]]; then
        log_warn "forge-tui returned empty response"
        return 1
    fi
    
    [[ "$(jq -r '.cancelled' <<< "$_json" 2>/dev/null)" == "true" ]]
}

if [[ -n "$FORGE_TUI_DAEMON" ]]; then
    trap '[[ -S "$FORGE_TUI_SOCKET" ]] && printf '"'"'{"widget":"quit"}\n'"'"' | nc -U "$FORGE_TUI_SOCKET" 2>/dev/null; rm -f "$FORGE_TUI_SOCKET"' EXIT
fi

tui_msg() {
    local title="${1}" msg="${2}"
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    printf '%s\n' "${msg}" >&2
    _forge '{"widget":"msg","title":"'"${title//\"/\\\"}"'","message":"'"${msg//\"/\\\"}"'"}' >/dev/null
}

tui_yesno() {
    local title="${1}" msg="${2}"
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    printf '%s\n' "${msg}" >&2
    msg="${msg//$'\n'/\\n}"
    local result
    result=$(_forge_result '{"widget":"yesno","title":"'"${title//\"/\\\"}"'","message":"'"${msg//\"/\\\"}"'"}')
    [[ "$result" == "true" ]] && return 0 || return 1
}

tui_input() {
    local title="${1}" msg="${2}" default="${3:-}"
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    [[ -n "${msg}" ]] && printf '%s\n' "${msg}" >&2
    msg="${msg//$'\n'/\\n}"
    _forge_result '{"widget":"input","title":"'"${title//\"/\\\"}"'","message":"'"${msg//\"/\\\"}"'","default":"'"${default//\"/\\\"}"'"}'
}

tui_password() {
    local title="${1}" msg="${2}"
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    [[ -n "${msg}" ]] && printf '%s\n' "${msg}" >&2
    msg="${msg//$'\n'/\\n}"
    _forge_result '{"widget":"password","title":"'"${title//\"/\\\"}"'","message":"'"${msg//\"/\\\"}"'"}'
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
    msg="${msg//$'\n'/\\n}"
    local choices_json
    choices_json=$(printf '%s\n' "$@" | jq -R . | jq -s .)
    _forge_result '{"widget":"menu","title":"'"${title//\"/\\\"}"'","message":"'"${msg//\"/\\\"}"'","choices":'"${choices_json}"'}'
}

tui_menu_custom() {
    local title="${1}" msg="${2}" height="${3:-15}"
    shift 3
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    [[ -n "${msg}" ]] && printf '%s\n' "${msg}" >&2
    msg="${msg//$'\n'/\\n}"
    local choices_json
    choices_json=$(printf '%s\n' "$@" | jq -R . | jq -s .)
    _forge_result '{"widget":"menu","title":"'"${title//\"/\\\"}"'","message":"'"${msg//\"/\\\"}"'","choices":'"${choices_json}"',"height":'"${height}"'}'
}

tui_checklist() {
    local title="${1}" msg="${2}"
    shift 2
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    [[ -n "${msg}" ]] && printf '%s\n' "${msg}" >&2
    msg="${msg//$'\n'/\\n}"
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
    msg="${msg//$'\n'/\\n}"
    local choices_json
    choices_json=$(printf '%s\n' "$@" | jq -R . | jq -s .)
    _forge_result '{"widget":"filter","title":"'"${title//\"/\\\"}"'","message":"'"${msg//\"/\\\"}"'","choices":'"${choices_json}"'}'
}

tui_radiolist() { tui_menu "$@"; }

tui_spin() {
    local title="${1}" cmd="${2}"
    if [[ -n "$FORGE_TUI_DAEMON" ]]; then
        local escaped_cmd
        escaped_cmd=$(jq -n --arg c "$cmd" '$c')
        printf '{"widget":"progress","title":"%s","command":["bash","-c",%s]}\n' \
            "${title//\"/\\\"}" "${escaped_cmd}" \
            | nc -U "$FORGE_TUI_SOCKET" 2>/dev/null \
            | while IFS= read -r line; do
                if [[ "$line" == '{"result":"done"}' ]] || [[ "$line" == '{"result":'* ]]; then
                    break
                fi
                log_info "${line}"
            done
    else
        bash -c "${cmd}" 2>&1 | while IFS= read -r line; do log_info "${line}"; done
    fi
}

tui_show_file() {
    local title="${1}" file="${2}"
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    _forge '{"widget":"summary","title":"'"${title//\"/\\\"}"'","file":"'"${file}"'"}' >/dev/null
}

tui_edit() {
    local title="${1}" file="${2}"
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    _forge '{"widget":"text","title":"'"${title//\"/\\\"}"'","file":"'"${file}"'"}' >/dev/null
}

tui_disk() {
    local title="${1}" disk="${2}" partitions_json="${3:-}" free_space_json="${4:-}" readonly="${5:-false}"
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    _forge_result '{"widget":"disk","title":"'"${title//\"/\\\"}"'","disk":"'"${disk}"'","partitions":'"${partitions_json:-[]}"',"free_space":'"${free_space_json:-[]}"',"readonly":'"${readonly}"'}'
}

tui_multiselect() {
    local title="${1}" msg="${2}" placeholder="${3:-}" min="${4:-0}" max="${5:-0}"
    shift 5 2>/dev/null || shift 3
    printf '\e[1;%sm── %s ──\e[0m\n' "$(theme_ansi_code "${GUM_TITLE_COLOR}")" "${title}" >&2
    [[ -n "${msg}" ]] && printf '%s\n' "${msg}" >&2
    local choices_json
    choices_json=$(printf '%s\n' "$@" | jq -R . | jq -s .)
    local json
    json='{"widget":"multiselect","title":"'"${title//\"/\\\"}"'","message":"'"${msg//\"/\\\"}"'","choices":'"${choices_json}"''
    [[ -n "$placeholder" ]] && json+=',"placeholder":"'"${placeholder//\"/\\\"}"'"'
    [[ "$min" != "0" ]] && json+=',"min":'"${min}"
    [[ "$max" != "0" ]] && json+=',"max":'"${max}"
    json+='}'
    _forge_result "$json"
}

tui_hub() {
    local title="${1}" categories_json="${2}" actions_json="${3}"
    _forge_result '{"widget":"hub","title":"'"${title//\"/\\\"}"'","categories":'"${categories_json}"',"actions":'"${actions_json}"'}'
}

tui_recovery() {
    local title="${1}" status_json="${2}" repairs_json="${3}"
    _forge_result '{"widget":"recovery","title":"'"${title//\"/\\\"}"'","status":'"${status_json}"',"repairs":'"${repairs_json}"'}'
}

tui_iso() {
    local title="${1}" categories_json="${2}"
    _forge_result '{"widget":"iso","title":"'"${title//\"/\\\"}"'","categories":'"${categories_json}"'}'
}

tui_migration_init() {
    local title="${1}" current_init="${2}"
    _forge_result '{"widget":"migration_init","title":"'"${title//\"/\\\"}"'","current_init":"'"${current_init}"'"}'
}

tui_migration_desktop() {
    local title="${1}" current_de="${2}"
    _forge_result '{"widget":"migration_desktop","title":"'"${title//\"/\\\"}"'","current_de":"'"${current_de}"'"}'
}

tui_poweruser() {
    local title="${1}" categories_json="${2}"
    _forge_result '{"widget":"poweruser","title":"'"${title//\"/\\\"}"'","categories":'"${categories_json}"'}'
}