#!/usr/bin/env bash
set -Eeuo pipefail

stage_poweruser() {
    if stage_should_skip poweruser; then return 0; fi

    [[ "$(state_get POWER_USER no)" == "yes" ]] || {
        log_warn "Power User mode not enabled, skipping source builds."
        stage_mark_done poweruser
        return 0
    }

    POWERUSER_DIR="${BASE_DIR}/poweruser"
    source "${POWERUSER_DIR}/lib/common.sh"
    source "${POWERUSER_DIR}/lib/flags.bash"
    source "${POWERUSER_DIR}/lib/recipe.bash"
    source "${POWERUSER_DIR}/lib/deps.bash"
    source "${POWERUSER_DIR}/lib/queue.bash"
    source "${POWERUSER_DIR}/lib/builder.bash"
    source "${POWERUSER_DIR}/lib/cache.bash"
    source "${POWERUSER_DIR}/lib/validate.bash"
    source "${POWERUSER_DIR}/tui/progress.sh"

    local profile_name
    profile_name="$(state_get POWERUSER_PROFILE default)"
    load_profile "${profile_name}"

    if [[ ! -d /mnt/tmp ]]; then
        mkdir -p /mnt/tmp || die "/mnt/tmp does not exist and cannot be created"
    fi
    if [[ ! -w /mnt/tmp ]]; then
        die "/mnt/tmp is not writable. Is /mnt mounted?"
    fi
    log_info "Build target /mnt/tmp is writable"

    local -a selected_pkgs
    read -ra selected_pkgs <<< "$(state_get POWERUSER_PACKAGES)"
    [[ ${#selected_pkgs[@]} -gt 0 ]] || die "No packages selected for source build"

    local pkg
    for pkg in "${selected_pkgs[@]}"; do
        validate_recipe "${pkg}"
    done

    log_info "Resolving dependencies..."
    local -a build_order
    mapfile -t build_order < <(resolve_deps "${selected_pkgs[@]}")

    log_info "Build order: ${build_order[*]}"
    generate_queue "${build_order[@]}"

    local remaining
    while ! queue_all_done; do
        pkg="$(queue_next)"
        [[ -n "${pkg}" ]] || break

        remaining="$(queue_remaining)"
        log_info "[${pkg}] Building... (${remaining} remaining)"

        if gum confirm --timeout=10s --affirmative="Watch" --negative="Skip" \
            "Press Enter to watch ${pkg} build live (auto-skips in 10s)"; then
            gum pager < <(tail -f "${POWERUSER_DIR}/build/logs/${pkg}.log" 2>/dev/null) &
            local pager_pid=$!
            build_package "${pkg}"
            local build_rc=$?
            kill "${pager_pid}" 2>/dev/null || true
            wait "${pager_pid}" 2>/dev/null || true
        else
            build_package "${pkg}"
            local build_rc=$?
        fi

        if [[ ${build_rc} -eq 0 ]]; then
            queue_mark "${pkg}" "done"
        else
            queue_mark "${pkg}" "failed"
            die "Build failed for ${pkg}"
        fi
    done

    mkdir -p /mnt/etc/artix-poweruser
    printf '%s\n' "${selected_pkgs[@]}" > /mnt/etc/artix-poweruser/world.txt
    log_info "World file written to /etc/artix-poweruser/world.txt"

    mkdir -p /mnt/usr/local/bin /mnt/usr/share/artix-poweruser/{lib,tui,recipes,db,profile,build/{sources,artifacts,work,queue,logs}}
    cp "${POWERUSER_DIR}/bin/gartix" /mnt/usr/local/bin/gartix
    chmod +x /mnt/usr/local/bin/gartix

    cp "${POWERUSER_DIR}/lib"/{common.sh,flags,recipe,validate,builder,cache,rebuild}.bash /mnt/usr/share/artix-poweruser/lib/ 2>/dev/null || true
    cp "${POWERUSER_DIR}/lib/common.sh" /mnt/usr/share/artix-poweruser/lib/ 2>/dev/null || true

    cp "${POWERUSER_DIR}/profile"/*.sh /mnt/usr/share/artix-poweruser/profile/
    echo "${profile_name}" > /mnt/usr/share/artix-poweruser/profile/active

    cp "${POWERUSER_DIR}/VERSION" /mnt/usr/share/artix-poweruser/VERSION
    cp "${POWERUSER_DIR}/recipes"/*.sh /mnt/usr/share/artix-poweruser/recipes/

    touch /mnt/usr/share/artix-poweruser/db/local.db
    cp "${POWERUSER_DIR}/db/local.db" /mnt/usr/share/artix-poweruser/db/local.db 2>/dev/null || true

    log_info "gartix and all dependencies installed to target"

    tui_build_timing_summary
    validate_system

    log_info "All source packages built and installed."
    stage_mark_done poweruser
}