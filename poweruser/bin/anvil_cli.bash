#!/usr/bin/env bash
set -Eeuo pipefail

fetch_recipe() {
    local name="${1}"
    require_root
    load_sections
    [[ -f "${LOCAL_LIST}" ]] || fetch_list || die "No recipe list available."

    local section
    section=$(awk -F'|' -v pkg="${name}" '$1 == pkg {print $2}' "${LOCAL_LIST}")
    [[ -n "${section}" ]] || { echo "Recipe '${name}' not found in .LIST"; return 1; }

    local allowed=0
    for s in ${ANVIL_SECTIONS}; do
        [[ "${section}" == "${s}" ]] && allowed=1 && break
    done
    [[ ${allowed} -eq 1 ]] || {
        echo "Section '${section}' is not enabled. Enable it with: anvil sections"
        return 1
    }

    local url="${RECIPES_REPO}/${section}/${name}.sh"
    local dest="${POWERUSER_DIR}/recipes/${name}.sh"

    if [[ -f "${dest}" ]]; then
        if ! tui_yesno "Overwrite?" "${name}.sh already exists. Overwrite?"; then
            return 0
        fi
        cp "${dest}" "${POWERUSER_DIR}/recipes.old/${name}.sh.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
    fi

    mkdir -p "${POWERUSER_DIR}/recipes.old"
    log_info "Downloading ${name}.sh from ${section}..."
    curl -sL "${url}" -o "${dest}" || { log_error "Failed to download ${url}"; return 1; }
    echo "Recipe ${name} downloaded to ${dest}"
}

fetch_all_sources() {
    require_root
    load_sections
    [[ -f "${LOCAL_LIST}" ]] || fetch_list || { echo "No recipe list."; return 1; }

    source "${POWERUSER_DIR}/lib/common.sh"
    source "${POWERUSER_DIR}/lib/recipe.bash"
    source "${POWERUSER_DIR}/lib/builder.bash"

    local IFS='|'
    while read -r name section desc; do
        local allowed=0
        for s in ${ANVIL_SECTIONS}; do
            [[ "${section}" == "${s}" ]] && allowed=1 && break
        done
        [[ ${allowed} -eq 0 ]] && continue
        echo "[*] Fetching sources for ${name}..."
        load_recipe "${name}" 2>/dev/null || {
            log_warn "Recipe ${name} not installed locally — skipping source fetch. Use 'fetch-recipe ${name}' first."
            continue
        }
        fetch_sources "${name}" 2>&1 || log_warn "Failed to fetch ${name}"
    done < "${LOCAL_LIST}"
    echo "[*] All available sources downloaded. You can now build offline."
}

sync_recipes() {
    require_root
    load_sections
    fetch_list || return 1

    echo "Available recipes (enabled sections: ${ANVIL_SECTIONS}):"
    list_available
    echo ""
    if tui_yesno "Update all?" "Download/update all enabled recipes from the community repo?"; then
        local IFS='|'
        while read -r name section desc; do
            local allowed=0
            for s in ${ANVIL_SECTIONS}; do
                [[ "${section}" == "${s}" ]] && allowed=1 && break
            done
            [[ ${allowed} -eq 0 ]] && continue
            echo "[*] Updating ${name}..."
            local url="${RECIPES_REPO}/${section}/${name}.sh"
            local dest="${POWERUSER_DIR}/recipes/${name}.sh"
            curl -sL "${url}" -o "${dest}" || log_warn "Failed to download ${name}"
        done < "${LOCAL_LIST}"
        echo "All enabled recipes updated."
    fi
}

rebuild_package() {
    local pkg="${1}"
    require_root
    source "${POWERUSER_DIR}/lib/common.sh"
    source "${POWERUSER_DIR}/lib/flags.bash"
    source "${POWERUSER_DIR}/lib/recipe.bash"
    source "${POWERUSER_DIR}/lib/validate.bash"
    source "${POWERUSER_DIR}/lib/builder.bash"
    source "${POWERUSER_DIR}/lib/cache.bash"
    source "${POWERUSER_DIR}/lib/rebuild.bash"

    load_profile "$(cat ${POWERUSER_DIR}/profile/active 2>/dev/null || echo default)"
    load_recipe "${pkg}"

    if ! needs_rebuild "${pkg}"; then
        echo "${pkg} is up-to-date. Nothing to rebuild."
        return 0
    fi

    echo "Rebuilding ${pkg}..."
    build_package "${pkg}"
}

new_recipe() {
    local name="${1}"
    local recipe_file="${POWERUSER_DIR}/recipes/${name}.sh"
    if [[ -f "${recipe_file}" ]]; then
        echo "Recipe ${name} already exists. Use 'edit' to modify it."
        exit 1
    fi
    cp "${POWERUSER_DIR}/recipes/template.sh" "${recipe_file}"
    ${EDITOR:-nano} "${recipe_file}"
    echo "Recipe ${name} created. Run 'anvil lint ${name}' to validate."
}

edit_recipe() {
    local name="${1}"
    local recipe_file="${POWERUSER_DIR}/recipes/${name}.sh"
    [[ -f "${recipe_file}" ]] || { echo "Recipe ${name} not found."; exit 1; }
    ${EDITOR:-nano} "${recipe_file}"
}

edit_config() {
    require_root
    local config_file="/boot/config-$(uname -r)"
    if [[ -f "${config_file}" ]]; then
        ${EDITOR:-nano} "${config_file}"
    else
        echo "No config found at ${config_file}"
        echo "Run 'anvil rebuild linux' to regenerate the kernel and its config."
        exit 1
    fi
    echo "Config edited. Rebuild with: anvil rebuild linux"
}

launch_menuconfig() {
    require_root
    local src_dir="/usr/src/linux-custom"
    if [[ -d "${src_dir}" ]]; then
        cd "${src_dir}"
        make menuconfig
        echo "Config saved. Rebuild with: anvil rebuild linux"
    else
        echo "Kernel source not found at ${src_dir}"
        echo "Run 'anvil fetch-source linux' to download the kernel source."
        exit 1
    fi
}

fetch_source() {
    local pkg="${1}"
    require_root
    source "${POWERUSER_DIR}/lib/common.sh"
    source "${POWERUSER_DIR}/lib/flags.bash"
    source "${POWERUSER_DIR}/lib/recipe.bash"
    source "${POWERUSER_DIR}/lib/builder.bash"

    load_recipe "${pkg}"
    fetch_sources "${pkg}"
    local src_dir="/usr/src/linux-custom"
    mkdir -p "${src_dir}"
    cd "${src_dir}"
    export BUILD_DIR="${src_dir}"
    export SOURCES_DIR="${POWERUSER_BUILD_DIR:-/var/cache/artix-poweruser}/sources"
    mkdir -p "${SOURCES_DIR}"
    fetch_sources "${pkg}" 2>/dev/null
    if declare -f prepare >/dev/null 2>&1; then
        prepare
    fi
    echo "Source ready in ${src_dir}"
}

lint_recipe() {
    local name="${1}"
    source "${POWERUSER_DIR}/lib/recipe.bash"
    source "${POWERUSER_DIR}/lib/validate.bash"
    if validate_recipe "${name}" 2>&1; then
        echo "Recipe ${name} is valid."
    else
        echo "Recipe ${name} has errors (see above)."
        exit 1
    fi
}

checksum_recipe() {
    local name="${1}"
    source "${POWERUSER_DIR}/lib/common.sh"
    source "${POWERUSER_DIR}/lib/recipe.bash"
    load_recipe "${name}"
    
    local url filename hash
    for src in "${sources[@]}"; do
        url="${src%%|*}"
        filename="${src##*|}"
        log_info "Fetching ${filename}..."
        curl -L -o "/tmp/${filename}" "${url}" || { log_error "Failed to fetch ${url}"; continue; }
        hash=$(sha256sum "/tmp/${filename}" | cut -d' ' -f1)
        printf '%s|%s|%s\n' "${url}" "${hash}" "${filename}"
        rm -f "/tmp/${filename}"
    done
}

_anvil_diff_recipe() {
    local name="${1}" old_file="${2}" new_file="${3}"

    if [[ ! -f "${old_file}" ]]; then
        _filly_send '{"widget":"msg","params":{"title":"New Recipe: '"${name}"'","message":"This is a new recipe. No diff available."}}' >/dev/null
        return 0
    fi

    local old_content new_content
    old_content=$(cat "${old_file}" | sed 's/"/\\"/g' | tr '\n' ' ')
    new_content=$(cat "${new_file}" | sed 's/"/\\"/g' | tr '\n' ' ')

    local left_widget right_widget
    left_widget=$(printf '{"widget":"msg","params":{"title":"Old: %s","message":"%s"}}' "${name}" "${old_content}")
    right_widget=$(printf '{"widget":"msg","params":{"title":"New: %s","message":"%s"}}' "${name}" "${new_content}")

    local diff_json
    diff_json=$(printf '{"widget":"split_panes","params":{"orientation":"horizontal","first":%s,"second":%s}}' \
        "${left_widget}" "${right_widget}")

    "${FILLY_BIN}" oneshot --input <(printf '%s\n' "${diff_json}") 2>/dev/null >/dev/null
}

upgrade_anvil() {
    require_root
    local recipe_dir="${POWERUSER_DIR}/recipes"
    local backup_dir="${POWERUSER_DIR}/recipes.old"
    local version_file="${POWERUSER_DIR}/VERSION"
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_path="${backup_dir}/${timestamp}"

    local current_version="unknown"
    [[ -f "${version_file}" ]] && current_version=$(tr -d '[:space:]' < "${version_file}")

    local remote_version=""
    if [[ -d "${recipe_dir}/.git" ]]; then
        remote_version=$(cd "${recipe_dir}" && git ls-remote origin HEAD 2>/dev/null | cut -f1)
        remote_version="${remote_version:0:8}"
    fi

    echo "[*] Installed Power User version: ${current_version}"
    echo "[*] Latest available version: ${remote_version:-unknown}"

    if [[ "${current_version}" == "${remote_version}" ]] && [[ -n "${remote_version}" ]]; then
        echo "[*] Already up-to-date. Nothing to upgrade."
        return 0
    fi

    echo "[*] Backing up current recipes to ${backup_path}..."
    mkdir -p "${backup_path}"
    if compgen -G "${recipe_dir}/*.sh" >/dev/null 2>&1; then
        cp -a "${recipe_dir}"/*.sh "${backup_path}/" 2>/dev/null || true
    fi

    [[ -f "${version_file}" ]] && cp "${version_file}" "${backup_path}/VERSION"

    echo "[*] Pulling latest recipes..."
    if [[ -d "${recipe_dir}/.git" ]]; then
        cd "${recipe_dir}"
        local before after
        before=$(git rev-parse HEAD 2>/dev/null | cut -c1-8 || echo "unknown")
        git pull 2>&1 || { echo "[!] git pull failed."; return 1; }
        after=$(git rev-parse HEAD 2>/dev/null | cut -c1-8 || echo "unknown")
        echo "[*] Updated from ${before} to ${after}"
    else
        echo "[!] Recipe directory is not a git repository. Manual update required."
        return 1
    fi

    if [[ -f "${recipe_dir}/../VERSION" ]]; then
        cp "${recipe_dir}/../VERSION" "${version_file}"
        local new_version
        new_version=$(tr -d '[:space:]' < "${version_file}")
        echo "[*] Power User updated to v${new_version}"
    fi

    echo "[*] Checking for changed recipes..."
    local changed=()
    for recipe in "${recipe_dir}"/*.sh; do
        [[ -f "${recipe}" ]] || continue
        local name
        name=$(basename "${recipe}")
        if [[ -f "${backup_path}/${name}" ]]; then
            if ! cmp -s "${recipe}" "${backup_path}/${name}"; then
                changed+=("${name}")
            fi
        else
            changed+=("${name} (new)")
        fi
    done

    if [[ ${#changed[@]} -gt 0 ]]; then
        echo "[*] Changed or new recipes:"
        for c in "${changed[@]}"; do
            echo "    - ${c}"
        done
        echo ""

        if tui_yesno "Review Changes" "Review diffs for changed recipes?"; then
            for c in "${changed[@]}"; do
                local name="${c% (new)}"
                local is_new=0
                [[ "${c}" == *" (new)" ]] && is_new=1

                local old_file="${backup_path}/${name}"
                local new_file="${recipe_dir}/${name}"

                if [[ ${is_new} -eq 1 ]]; then
                    _filly_send '{"widget":"msg","params":{"title":"New Recipe: '"${name}"'","message":"This recipe was added in this update."}}' >/dev/null
                elif [[ -f "${old_file}" && -f "${new_file}" ]]; then
                    _anvil_diff_recipe "${name}" "${old_file}" "${new_file}"
                fi
            done
        fi

        echo "[*] Old recipes saved to ${backup_path}"
        echo "[*] Run 'anvil rebuild <recipe>' for any changed packages."
    else
        echo "[*] No recipe changes detected."
    fi
}

cache_clean() {
    require_root
    source "${POWERUSER_DIR}/lib/cache.bash"
    cache_clean
}