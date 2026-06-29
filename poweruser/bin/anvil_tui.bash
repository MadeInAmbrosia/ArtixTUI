#!/usr/bin/env bash
set -Eeuo pipefail

FORGE_TUI="${FORGE_TUI:-forge-tui}"

_forge() {
    local _dir _tmp _out
    _dir=$(mktemp -d --tmpdir anvil-tui-XXXXXX)
    chmod 700 "$_dir"
    _tmp="$_dir/input.json"
    _out="$_dir/output.json"
    printf '%s\n' "$1" > "$_tmp"
    "$FORGE_TUI" --mode widget --input "$_tmp" --output "$_out" < /dev/tty > /dev/tty 2>/dev/null
    cat "$_out" 2>/dev/null
}

_forge_result() {
    local _json
    _json=$(_forge "$1")
    jq -r 'if .result | type == "array" then .result[] else .result // .selected // empty end' <<< "$_json" 2>/dev/null
}

_forge_cancelled() {
    local _json
    _json=$(_forge "$1")
    [[ "$(jq -r '.cancelled' <<< "$_json" 2>/dev/null)" == "true" ]]
}

tui_menu() {
    local title="${1}" msg="${2}"
    shift 2
    msg="${msg//$'\n'/\\n}"
    local choices_json
    choices_json=$(printf '%s\n' "$@" | jq -R . | jq -s .)
    _forge_result '{"widget":"menu","title":"'"${title//\"/\\\"}"'","message":"'"${msg//\"/\\\"}"'","choices":'"${choices_json}"'}'
}

tui_checklist() {
    local title="${1}" msg="${2}"
    shift 2
    msg="${msg//$'\n'/\\n}"
    local choices_json result
    choices_json=$(printf '%s\n' "$@" | jq -R . | jq -s .)
    result=$(_forge_result '{"widget":"checklist","title":"'"${title//\"/\\\"}"'","message":"'"${msg//\"/\\\"}"'","choices":'"${choices_json}"'}')
    printf '%s\n' "${result}"
}

tui_msg() {
    local title="${1}" msg="${2}"
    msg="${msg//$'\n'/\\n}"
    _forge '{"widget":"msg","title":"'"${title//\"/\\\"}"'","message":"'"${msg//\"/\\\"}"'"}' >/dev/null
}

tui_input() {
    local title="${1}" msg="${2}" default="${3:-}"
    msg="${msg//$'\n'/\\n}"
    _forge_result '{"widget":"input","title":"'"${title//\"/\\\"}"'","message":"'"${msg//\"/\\\"}"'","default":"'"${default//\"/\\\"}"'"}'
}

tui_yesno() {
    local title="${1}" msg="${2}"
    msg="${msg//$'\n'/\\n}"
    local result
    result=$(_forge_result '{"widget":"yesno","title":"'"${title//\"/\\\"}"'","message":"'"${msg//\"/\\\"}"'"}')
    [[ "$result" == "true" ]] && return 0 || return 1
}

tui_manage_sections() {
    load_sections
    local chosen
    chosen=$(tui_checklist "Recipe Sections" "Select which recipe sections to enable:" \
        "OFFICIAL/Base (recommended)" \
        "OFFICIAL/Other (extended, tested)" \
        "COMMUNITY/Base (pending review)" \
        "COMMUNITY/Other (experimental)") || return 0

    ANVIL_SECTIONS="${chosen//$'\n'/ }"
    [[ -z "${ANVIL_SECTIONS}" ]] && ANVIL_SECTIONS="${DEFAULT_SECTIONS}"
    save_sections
    tui_msg "Sections Updated" "Enabled sections: ${ANVIL_SECTIONS}"
}

tui_main() {
    while true; do
        clear
        local action
        action=$(tui_menu "anvil" "Select an action:" \
            "List installed packages" \
            "List available recipes" \
            "Package info" \
            "Rebuild a package" \
            "Create new recipe" \
            "Edit recipe" \
            "Edit kernel config" \
            "Menuconfig" \
            "Fetch kernel source" \
            "Fetch a recipe from repo" \
            "Fetch all sources" \
            "Manage recipe sections" \
            "Lint recipe" \
            "Checksum recipe" \
            "Sync recipes" \
            "Recovery – check & repair source packages" \
            "Upgrade recipes" \
            "Clean cache" \
            "Quit") || break

        case "$action" in
            "List installed packages")
                local installed
                installed=$(list_packages 2>/dev/null)
                tui_msg "Installed Packages" "${installed:-No packages installed.}"
                ;;
            "List available recipes")
                local recipes
                recipes=$(list_recipes 2>/dev/null)
                tui_msg "Available Recipes" "${recipes:-No recipes found.}"
                ;;
            "Package info")
                local pkg_list
                pkg_list=$(list_packages 2>/dev/null | awk '{print $1}')
                if [[ -z "$pkg_list" ]]; then
                    tui_msg "No packages" "No source packages installed yet."
                    continue
                fi
                local pkg
                pkg=$(tui_menu "Select Package" "" $pkg_list) || continue
                local info
                info=$(info_package "$pkg")
                tui_msg "Package Info: $pkg" "$info"
                ;;
            "Rebuild a package")
                local avail
                avail=$(list_recipes 2>/dev/null | awk '{print $1}')
                if [[ -z "$avail" ]]; then
                    tui_msg "No recipes" "No recipes found."
                    continue
                fi
                local to_rebuild
                to_rebuild=$(tui_menu "Select package" "" $avail) || continue
                rebuild_package "$to_rebuild"
                tui_msg "Rebuild" "$to_rebuild rebuilt."
                ;;
            "Create new recipe")
                local name
                name=$(tui_input "New Recipe" "Package name:") || continue
                [[ -z "$name" ]] && continue
                new_recipe "$name"
                ;;
            "Edit recipe")
                local avail2
                avail2=$(list_recipes 2>/dev/null | awk '{print $1}')
                if [[ -z "$avail2" ]]; then
                    tui_msg "No recipes" "No recipes found."
                    continue
                fi
                local to_edit
                to_edit=$(tui_menu "Select recipe" "" $avail2) || continue
                edit_recipe "$to_edit"
                ;;
            "Edit kernel config")
                edit_config
                tui_msg "Config" "Kernel config edited."
                ;;
            "Menuconfig")
                launch_menuconfig
                tui_msg "Menuconfig" "Kernel configuration complete."
                ;;
            "Fetch kernel source")
                fetch_source linux
                tui_msg "Source" "Kernel source ready in /usr/src/linux-custom"
                ;;
            "Fetch a recipe from repo")
                local remote_recipes
                remote_recipes=$(list_available 2>/dev/null | awk '{print $1}')
                if [[ -z "$remote_recipes" ]]; then
                    tui_msg "No recipes" "No recipes available from the community repo."
                    continue
                fi
                local to_fetch
                to_fetch=$(tui_menu "Select recipe" "" ${remote_recipes}) || continue
                fetch_recipe "$to_fetch"
                tui_msg "Fetch Recipe" "${to_fetch} downloaded."
                ;;
            "Fetch all sources")
                fetch_all_sources
                tui_msg "Fetch All" "All recipe sources downloaded."
                ;;
            "Manage recipe sections")
                tui_manage_sections
                ;;
            "Lint recipe")
                local avail3
                avail3=$(list_recipes 2>/dev/null | awk '{print $1}')
                if [[ -z "$avail3" ]]; then
                    tui_msg "No recipes" "No recipes found."
                    continue
                fi
                local to_lint
                to_lint=$(tui_menu "Select recipe" "" $avail3) || continue
                local lint_result
                lint_result=$(lint_recipe "$to_lint" 2>&1)
                tui_msg "Lint Result: $to_lint" "$lint_result"
                ;;
            "Checksum recipe")
                local avail4
                avail4=$(list_recipes 2>/dev/null | awk '{print $1}')
                if [[ -z "$avail4" ]]; then
                    tui_msg "No recipes" "No recipes found."
                    continue
                fi
                local to_checksum
                to_checksum=$(tui_menu "Select recipe" "" $avail4) || continue
                local checksum_result
                checksum_result=$(checksum_recipe "$to_checksum" 2>&1)
                tui_msg "Checksums: $to_checksum" "${checksum_result}"
                ;;
            "Sync recipes")
                sync_recipes
                tui_msg "Sync" "Recipes synchronized."
                ;;
            "Recovery – check & repair source packages")
                anvil_recovery_status
                if tui_yesno "Repair source packages?" "Attempt to repair all source-built packages?"; then
                    local repaired=()
                    while IFS='|' read -r pkgname _; do
                        [[ -n "${pkgname}" ]] || continue
                        anvil_recovery_repair "${pkgname}" && repaired+=("${pkgname}")
                    done < <(tail -n +2 "${POWERUSER_DIR}/db/local.db" 2>/dev/null)
                    if [[ ${#repaired[@]} -gt 0 ]]; then
                        tui_msg "Recovery Complete" "Repaired: ${repaired[*]}"
                    else
                        tui_msg "Recovery" "No packages were repaired."
                    fi
                fi
                ;;
            "Upgrade recipes")
                upgrade_anvil
                tui_msg "Upgrade" "Recipes upgraded. Old recipes backed up."
                ;;
            "Clean cache")
                cache_clean
                tui_msg "Cache" "Obsolete packages removed."
                ;;
            "Quit") break ;;
        esac
    done
    clear
}