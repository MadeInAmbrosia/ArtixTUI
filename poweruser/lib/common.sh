#!/usr/bin/env bash
set -Eeuo pipefail

die() {
    printf '\e[1;31m[✗] %s\e[0m\n' "${1:-fatal error}" >&2
    exit 1
}

log_info()  { printf '\e[1;34m[*] %s\e[0m\n' "$*" >&2; }
log_warn()  { printf '\e[1;33m[!] %s\e[0m\n' "$*" >&2; }
log_error() { printf '\e[1;31m[✗] %s\e[0m\n' "$*" >&2; }

require_root() {
    [[ $EUID -eq 0 ]] || die "This command must be run as root"
}