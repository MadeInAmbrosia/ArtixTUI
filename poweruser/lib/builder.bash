#!/usr/bin/env bash
set -Eeuo pipefail

POWERUSER_BUILD_DIR="${POWERUSER_BUILD_DIR:-/mnt/artix-poweruser}"
SOURCES_DIR="${POWERUSER_BUILD_DIR}/sources"
WORK_DIR="${POWERUSER_BUILD_DIR}/work"
ARTIFACTS_DIR="${POWERUSER_BUILD_DIR}/artifacts"
LOGS_DIR="${POWERUSER_DIR}/build/logs"
mkdir -p "${SOURCES_DIR}" "${WORK_DIR}" "${ARTIFACTS_DIR}" "${LOGS_DIR}"

source "${POWERUSER_DIR}/lib/validate.bash"
source "${POWERUSER_DIR}/lib/common.sh"

build_package() {
    local recipe_name="${1}"
    local log_file="${LOGS_DIR}/${recipe_name}.log"
    local start_time end_time duration

    load_recipe "${recipe_name}"

    local -a selected_features=()
    local feature_var="POWERUSER_FEATURES_${pkgname//-/_}"
    local saved_features
    saved_features="$(state_get "${feature_var}" "")"
    if [[ -n "${saved_features}" ]]; then
        read -ra selected_features <<< "${saved_features}"
    fi
    export selected_features

    local flags_h
    flags_h="$(flags_hash)"
    if grep -q "^${pkgname}|${pkgver}-${pkgrel}|${flags_h}|" "${POWERUSER_DIR}/db/local.db" 2>/dev/null; then
        log_info "${pkgname}-${pkgver} already built — skipping"
        return 0
    fi

    validate_recipe "${recipe_name}"

    log_info "Building ${pkgname}-${pkgver}"
    start_time=$(date +%s)

    if [[ ${#makedepends[@]} -gt 0 ]]; then
        log_info "  Installing build dependencies: ${makedepends[*]}"
        pacman -S --noconfirm --needed "${makedepends[@]}" >> "${log_file}" 2>&1 || {
            log_error "Failed installing deps on live system"
            return 1
        }
        artix-chroot /mnt pacman -S --noconfirm --needed "${makedepends[@]}" >> "${log_file}" 2>&1 || {
            log_error "Failed installing deps in target"
            return 1
        }
    fi

    local pkg_work="${WORK_DIR}/${pkgname}"
    rm -rf "${pkg_work}"
    mkdir -p "${pkg_work}"
    local PKG_DESTDIR="${pkg_work}/pkg"
    mkdir -p "${PKG_DESTDIR}"
    export BUILD_DIR="${pkg_work}"
    export SOURCES_DIR PKG_DESTDIR

    local has_skip=0
    for src in "${sources[@]}"; do
        local checksum="${src#*|}"; checksum="${checksum%%|*}"
        [[ "${checksum}" == "SKIP" ]] && has_skip=1 && break
    done
    if [[ ${has_skip} -eq 1 ]]; then
        log_warn "Some sources for ${pkgname} have no checksums — source integrity NOT verified"
        if ! tui_yesno "Unverified Sources" "${pkgname} has sources without SHA256 checksums. Continue anyway?"; then
            die "User aborted due to missing checksums"
        fi
    fi

    log_info "Build started for ${pkgname} — tail -f ${LOGS_DIR}/${recipe_name}.log to watch"

    if ! fetch_sources "${recipe_name}" >> "${log_file}" 2>&1; then
        handle_build_failure "${recipe_name}" "${log_file}" "${pkg_work}"
        return $?
    fi

    if declare -f prepare >/dev/null 2>&1; then
        log_info "  Preparing ${pkgname}..."
        if ! ( cd "${pkg_work}" && prepare ) >> "${log_file}" 2>&1; then
            handle_build_failure "${recipe_name}" "${log_file}" "${pkg_work}"
            return $?
        fi
    fi

    if declare -f configure >/dev/null 2>&1; then
        log_info "  Configuring ${pkgname}..."
        if ! ( cd "${pkg_work}" && configure ) >> "${log_file}" 2>&1; then
            handle_build_failure "${recipe_name}" "${log_file}" "${pkg_work}"
            return $?
        fi
    fi

    log_info "  Building ${pkgname}..."
    if ! ( cd "${pkg_work}" && build ) >> "${log_file}" 2>&1; then
        handle_build_failure "${recipe_name}" "${log_file}" "${pkg_work}"
        return $?
    fi

    if declare -f check >/dev/null 2>&1; then
        log_info "  Checking ${pkgname}..."
        if ! ( cd "${pkg_work}" && check ) >> "${log_file}" 2>&1; then
            log_warn "Check phase failed (non-fatal)"
        fi
    fi

    log_info "  Packaging ${pkgname}..."
    if ! ( cd "${pkg_work}" && package ) >> "${log_file}" 2>&1; then
        handle_build_failure "${recipe_name}" "${log_file}" "${pkg_work}"
        return $?
    fi

    log_info "  Installing ${pkgname}..."
    if [[ "${pkgname}" == "linux-custom" ]]; then
        mkdir -p /mnt/boot /mnt/usr/lib/modules
        cp -a "${PKG_DESTDIR}/boot/." /mnt/boot/ 2>>"${log_file}" || {
            log_error "Failed to copy kernel to /mnt/boot"
            handle_build_failure "${recipe_name}" "${log_file}" "${pkg_work}"
            return 1
        }
        if [[ -d "${PKG_DESTDIR}/lib/modules" ]]; then
            cp -a "${PKG_DESTDIR}/lib/modules/." /mnt/usr/lib/modules/ 2>>"${log_file}" || true
        fi
    else
        if ! ( cd "${PKG_DESTDIR}" && cp -a . /mnt/ ) 2>>"${log_file}"; then
            log_error "Failed to install ${pkgname} to /mnt"
            handle_build_failure "${recipe_name}" "${log_file}" "${pkg_work}"
            return 1
        fi
    fi

    flags_h="$(flags_hash)"
    printf '%s|%s-%s|%s|%s|%s\n' \
        "${pkgname}" "${pkgver}" "${pkgrel}" "${flags_h}" "$(date -I)" "${selected_features[*]}" \
        >> "${POWERUSER_DIR}/db/local.db"

    end_time=$(date +%s)
    duration=$((end_time - start_time))
    printf '%s|%s|%d\n' "${pkgname}" "success" "${duration}" >> "${LOGS_DIR}/timing.log"
    log_info "  ${pkgname} — done (${duration}s)"
    return 0
}

handle_build_failure() {
    local recipe_name="${1}" log="${2}" work_dir="${3}"
    log_error "Build failed for ${recipe_name}. Check ${log}"

    while true; do
        local action
        if [[ "${recipe_name}" == "linux" ]]; then
            action=$(tui_menu "Build Failed" "${recipe_name} failed." \
                "Retry" \
                "Skip" \
                "Debug shell" \
                "Update ArtixForge and retry" \
                "Install binary kernel instead" \
                "Abort") || action="Abort"
        else
            action=$(tui_menu "Build Failed" "${recipe_name} failed." \
                "Retry" \
                "Skip" \
                "Debug shell" \
                "Update ArtixForge and retry" \
                "Abort") || action="Abort"
        fi

        case "${action}" in
            Retry)
                log_info "Retrying ${recipe_name}..."
                rm -rf "${work_dir}"
                if build_package "${recipe_name}"; then
                    return 0
                fi
                ;;
            Skip)
                log_warn "Skipping ${recipe_name}"
                printf '%s|%s|%d\n' "${recipe_name}" "skipped" 0 >> "${LOGS_DIR}/timing.log"
                return 0
                ;;
            "Debug shell")
                log_info "Dropping to shell in ${work_dir}. Type 'exit' to return."
                ( cd "${work_dir}" && bash )
                ;;
            "Update ArtixForge and retry")
                log_info "Updating ArtixForge from GitHub..."
                local update_dir="/tmp/artixforge-update"
                rm -rf "${update_dir}"
                git clone --depth 1 https://github.com/realvolk/ArtixForge.git "${update_dir}" || {
                    log_error "Failed to clone ArtixForge"
                    continue
                }
                cp -a "${update_dir}/." "${BASE_DIR}/"
                rm -rf "${update_dir}"
                log_info "ArtixForge updated. Restarting pipeline..."
                cd "${BASE_DIR}"
                exec sudo ./install
                ;;
            "Install binary kernel instead")
                log_info "Installing binary kernel as fallback..."
                local kernel_choice kernel_pkg
                kernel_choice="$(state_get KERNEL_CHOICE linux)"
                case "${kernel_choice}" in
                    linux)          kernel_pkg="linux" ;;
                    linux-zen)      kernel_pkg="linux-zen" ;;
                    linux-lts)      kernel_pkg="linux-lts" ;;
                    linux-hardened) kernel_pkg="linux-hardened" ;;
                    *)              kernel_pkg="linux" ;;
                esac
                artix-chroot /mnt pacman -S --noconfirm "${kernel_pkg}" "${kernel_pkg}-headers" || {
                    log_error "Failed to install binary kernel"
                    continue
                }
                log_info "Binary kernel ${kernel_pkg} installed as fallback"
                state_set KEEP_BINARY_KERNEL "yes"
                printf '%s|%s|%d\n' "${recipe_name}" "binary-fallback" 0 >> "${LOGS_DIR}/timing.log"
                return 0
                ;;
            Abort)
                die "Build aborted by user"
                ;;
        esac
    done
}

fetch_sources() {
    local recipe_name="${1}"
    load_recipe "${recipe_name}"

    for src in "${sources[@]}"; do
        local url checksum filename
        url="${src%%|*}"
        checksum="${src#*|}"; checksum="${checksum%%|*}"
        filename="${src##*|}"

        local dest="${SOURCES_DIR}/${filename}"
        if [[ -f "${dest}" ]]; then
            local actual
            actual="$(sha256sum "${dest}" | cut -d' ' -f1)"
            if [[ "${actual}" == "${checksum}" ]]; then
                continue
            fi
        fi

        log_info "  Fetching ${filename}..."
        curl_resume "${url}" "${dest}" || { log_error "Download failed: ${url}"; return 1; }

        if [[ -n "${checksum}" && "${checksum}" != "SKIP" ]]; then
            local actual
            actual="$(sha256sum "${dest}" | cut -d' ' -f1)"
            [[ "${actual}" == "${checksum}" ]] || { log_error "Checksum mismatch: ${filename}"; return 1; }
        elif [[ "${checksum}" == "SKIP" ]]; then
            log_warn "Checksum verification SKIPPED for ${filename} — source integrity NOT verified"
        fi
    done
}