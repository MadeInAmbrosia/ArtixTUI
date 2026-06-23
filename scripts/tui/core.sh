#!/usr/bin/env bash
set -Eeuo pipefail

GUM_TITLE_COLOR="${GUM_TITLE_COLOR:-212}"
GUM_ACCENT_COLOR="${GUM_ACCENT_COLOR:-34}"

LOG_FILE="/tmp/artix-installer/install.log"
CHROOT_LOG="/mnt/var/log/artix-installer.log"

_ensure_log_dirs() {
    mkdir -p "$(dirname "${LOG_FILE}")"
    [[ -d /mnt ]] && mkdir -p "$(dirname "${CHROOT_LOG}")" 2>/dev/null || true
}

_gum_tty() {
    if [[ -c /dev/tty && -r /dev/tty && -w /dev/tty ]]; then
        printf '/dev/tty'
        return 0
    fi
    local tty
    tty=$(tty 2>/dev/null || true)
    if [[ -n "${tty}" && -c "${tty}" ]]; then
        printf '%s' "${tty}"
        return 0
    fi
    for console in /dev/tty1 /dev/tty2 /dev/tty3 /dev/tty0 /dev/console; do
        if [[ -c "${console}" && -r "${console}" && -w "${console}" ]]; then
            printf '%s' "${console}"
            return 0
        fi
    done
    return 1
}

theme_ansi() {
    local gum_code="${1:-212}"
    case "${gum_code}" in
        212) printf '\e[38;5;212m' ;;
        39)  printf '\e[38;5;39m' ;;
        245) printf '\e[38;5;245m' ;;
        250) printf '\e[38;5;250m' ;;
        3)   printf '\e[38;5;3m' ;;
        34)  printf '\e[38;5;34m' ;;
        117) printf '\e[38;5;117m' ;;
        196) printf '\e[38;5;196m' ;;
        255) printf '\e[38;5;255m' ;;
        11)  printf '\e[38;5;11m' ;;
        *)   printf '\e[38;5;%sm' "${gum_code}" ;;
    esac
}

log_info() {
    local msg="${1}"
    local colour
    colour=$(theme_ansi "${GUM_ACCENT_COLOR:-34}")
    _ensure_log_dirs
    printf '%s[*] %s\e[0m\n' "${colour}" "${msg}" | tee -a "${LOG_FILE}" >&2
    [[ -d /mnt ]] && printf '[*] %s\n' "${msg}" >> "${CHROOT_LOG}" 2>/dev/null || true
}

log_warn() {
    local msg="${1}"
    local colour
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

tui_msg() {
    local title="${1}" msg="${2}" tty
    tty=$(_gum_tty) || { printf '[!] No usable TTY for gum — tui_msg failed\n' >&2; return 1; }
    gum style --bold --foreground "${GUM_TITLE_COLOR}" "── ${title} ──"
    gum format "${msg}"
    gum confirm "Press Enter to continue" --affirmative="OK" --timeout=0 <"${tty}" 2>/dev/null || true
}

tui_yesno() {
    local title="${1}" msg="${2}" tty rc
    tty=$(_gum_tty) || { printf '[!] No usable TTY for gum — tui_yesno returning 1\n' >&2; return 1; }
    gum style --bold --foreground "${GUM_TITLE_COLOR}" "── ${title} ──"
    gum format "${msg}"
    gum confirm <"${tty}" 2>/dev/null
    rc=$?
    return ${rc}
}

tui_input() {
    local title="${1}" msg="${2}" default="${3:-}" result tty
    tty=$(_gum_tty) || { printf '%s\n' "${default}"; return 0; }
    gum style --bold --foreground "${GUM_TITLE_COLOR}" "── ${title} ──" >&2
    [[ -n "${msg}" ]] && gum format "${msg}" >&2
    result=$(gum input --value "${default}" --prompt "> " <"${tty}" 2>/dev/null) || true
    printf '%s' "${result}"
}

tui_password() {
    local title="${1}" msg="${2}" tty
    tty=$(_gum_tty) || { printf '[!] No usable TTY for password prompt\n' >&2; return 1; }
    gum style --bold --foreground "${GUM_TITLE_COLOR}" "── ${title} ──" >&2
    [[ -n "${msg}" ]] && gum format "${msg}" >&2
    gum input --password --prompt "> " <"${tty}" 2>/dev/null || true
}

tui_msg_quick() {
    local title="${1}" msg="${2}"
    gum style --bold --foreground "${GUM_TITLE_COLOR}" "── ${title} ──"
    gum format "${msg}"
}

tui_password_confirm() {
    local title="${1:-Password}" prompt="${2:-Enter password:}" confirm_prompt="${3:-Confirm password:}"
    local pass confirm tty
    tty=$(_gum_tty) || { printf '[!] No usable TTY for password prompt\n' >&2; return 1; }
    while true; do
        gum style --bold --foreground "${GUM_TITLE_COLOR}" "── ${title} ──" >&2
        pass=$(gum input --password --prompt "${prompt}: " <"${tty}" 2>/dev/null) || true
        [[ -n "${pass}" ]] || return 1
        confirm=$(gum input --password --prompt "${confirm_prompt}: " <"${tty}" 2>/dev/null) || true
        [[ -n "${confirm}" ]] || return 1
        if [[ "${pass}" == "${confirm}" ]]; then
            printf '%s\n' "${pass}"
            return 0
        fi
        tui_msg_quick "Mismatch" "Passwords do not match. Try again."
    done
}

tui_menu() {
    local title="${1}" msg="${2}" result tty
    shift 2
    tty=$(_gum_tty) || { printf '[!] No usable TTY for gum — tui_menu failed\n' >&2; return 1; }
    gum style --bold --foreground "${GUM_TITLE_COLOR}" "── ${title} ──" >&2
    [[ -n "${msg}" ]] && gum format "${msg}" >&2
    result=$(gum choose --height=15 "$@" <"${tty}" 2>/dev/null) || return 1
    printf '%s' "${result}"
}

tui_menu_custom() {
    local title="${1}" msg="${2}" height="${3:-15}" result tty
    shift 3
    tty=$(_gum_tty) || { printf '[!] No usable TTY for gum — tui_menu_custom failed\n' >&2; return 1; }
    gum style --bold --foreground "${GUM_TITLE_COLOR}" "── ${title} ──" >&2
    [[ -n "${msg}" ]] && gum format "${msg}" >&2
    result=$(gum choose --height="${height}" "$@" <"${tty}" 2>/dev/null) || return 1
    printf '%s' "${result}"
}

tui_checklist() {
    local title="${1}" msg="${2}" result tty
    shift 2
    tty=$(_gum_tty) || { printf '[!] No usable TTY for gum — tui_checklist failed\n' >&2; return 1; }
    gum style --bold --foreground "${GUM_TITLE_COLOR}" "── ${title} ──" >&2
    [[ -n "${msg}" ]] && gum format "${msg}" >&2
    result=$(gum choose --no-limit --height=15 "$@" <"${tty}" 2>/dev/null) || return 1
    printf '%s' "${result}"
}

tui_filter() {
    local title="${1}" msg="${2}" result tty
    shift 2
    tty=$(_gum_tty) || { printf '[!] No usable TTY for gum — tui_filter failed\n' >&2; return 1; }
    gum style --bold --foreground "${GUM_TITLE_COLOR}" "── ${title} ──" >&2
    [[ -n "${msg}" ]] && gum format "${msg}" >&2
    result=$(gum filter --height=20 "$@" <"${tty}" 2>/dev/null) || return 1
    printf '%s' "${result}"
}

tui_radiolist() {
    tui_menu "$@"
}

tui_spin() {
    local title="${1}" cmd="${2}"
    gum spin --spinner dot --title "${title}" -- bash -c "${cmd}" 2>&1 | while IFS= read -r line; do log_info "${line}"; done
}

tui_show_file() {
    local title="${1}" file="${2}"
    gum style --bold --foreground "${GUM_TITLE_COLOR}" "── ${title} ──"
    gum pager < "${file}"
}