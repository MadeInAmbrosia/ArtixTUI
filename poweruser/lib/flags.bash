#!/usr/bin/env bash
set -Eeuo pipefail

load_profile() {
    local profile_name="${1:-default}"
    local profile_file="${POWERUSER_DIR}/profile/${profile_name}.sh"
    [[ -f "${profile_file}" ]] || die "Profile not found: ${profile_name}"
    source "${profile_file}"
    export ARTIX_PROFILE="${profile_name}"
}

use_enable() {
    local flag="${1}"
    [[ " ${selected_features[*]:-} " =~ " ${flag} " ]] && return 0 || return 1
}

apply_pkg_flags() {
    ARTIX_CFLAGS="${PKG_CFLAGS:-${ARTIX_CFLAGS}}"
    ARTIX_CXXFLAGS="${PKG_CXXFLAGS:-${ARTIX_CXXFLAGS}}"
    ARTIX_LDFLAGS="${PKG_LDFLAGS:-${ARTIX_LDFLAGS}}"
    ARTIX_MAKEFLAGS="${PKG_MAKEFLAGS:-${ARTIX_MAKEFLAGS:-$(nproc)}}"
}

flags_hash() {
    local feature_string="${selected_features[*]:-}"
    feature_string="${feature_string:-none}"
    printf '%s%s%s%s%s' \
        "${ARTIX_CFLAGS}" "${ARTIX_CXXFLAGS}" "${ARTIX_LDFLAGS}" \
        "${ARTIX_MAKEFLAGS}" "${feature_string}" \
        | sha256sum | cut -d' ' -f1
}