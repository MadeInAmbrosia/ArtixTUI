#!/usr/bin/env bash
set -Eeuo pipefail

tui_menu() {
    local title="${1}" msg="${2}"
    shift 2
    gum style --bold --foreground "${GUM_TITLE_COLOR}" "── ${title} ──" >&2
    [[ -n "${msg}" ]] && gum format "${msg}" >&2
    gum choose --height=15 "$@" </dev/tty
}

tui_checklist() {
    local title="${1}" msg="${2}"
    shift 2
    gum style --bold --foreground "${GUM_TITLE_COLOR}" "── ${title} ──" >&2
    [[ -n "${msg}" ]] && gum format "${msg}" >&2
    gum choose --no-limit --height=15 "$@" </dev/tty
}

tui_msg() {
    local title="${1}" msg="${2}"
    gum style --bold --foreground "${GUM_TITLE_COLOR}" "── ${title} ──"
    gum format "${msg}"
    gum confirm "Press Enter to continue" --affirmative="OK" --timeout=0 </dev/tty 2>/dev/null || true
}

tui_input() {
    local title="${1}" msg="${2}" default="${3:-}" result
    gum style --bold --foreground "${GUM_TITLE_COLOR}" "── ${title} ──" >&2
    [[ -n "${msg}" ]] && gum format "${msg}" >&2
    result=$(gum input --value "${default}" --prompt "> " </dev/tty) || true
    printf '%s' "${result}"
}

tui_yesno() {
    local title="${1}" msg="${2}"
    gum style --bold --foreground "${GUM_TITLE_COLOR}" "── ${title} ──"
    gum format "${msg}"
    gum confirm </dev/tty
}

tui_manage_sections() {
    load_sections
    local chosen
    chosen=$(tui_checklist "Recipe Sections" "Select which recipe sections to enable:" \
        "OFFICIAL/Base (recommended)" \
        "OFFICIAL/Other (extended, tested)" \
        "COMMUNITY/Base (pending review)" \
        "COMMUNITY/Other (experimental)") || return 0

    GARTIX_SECTIONS="${chosen//$'\n'/ }"
    [[ -z "${GARTIX_SECTIONS}" ]] && GARTIX_SECTIONS="${DEFAULT_SECTIONS}"
    save_sections
    tui_msg "Sections Updated" "Enabled sections: ${GARTIX_SECTIONS}"
}

tui_main() {
    while true; do
        clear
        local action
        action=$(tui_menu "gartix" "Select an action:" \
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
                local installed=$(list_packages 2>/dev/null)
                tui_msg "Installed Packages" "${installed:-No packages installed.}"
                ;;
            "List available recipes")
                local recipes=$(list_recipes 2>/dev/null)
                tui_msg "Available Recipes" "${recipes:-No recipes found.}"
                ;;
            "Package info")
                local pkg_list=$(list_packages 2>/dev/null | awk '{print $1}')
                if [[ -z "$pkg_list" ]]; then
                    tui_msg "No packages" "No source packages installed yet."
                    continue
                fi
                local pkg=$(tui_menu "Select Package" "" $pkg_list) || continue
                local info=$(info_package "$pkg")
                tui_msg "Package Info: $pkg" "$info"
                ;;
            "Rebuild a package")
                local avail=$(list_recipes 2>/dev/null | awk '{print $1}')
                if [[ -z "$avail" ]]; then
                    tui_msg "No recipes" "No recipes found."
                    continue
                fi
                local to_rebuild=$(tui_menu "Select package" "" $avail) || continue
                rebuild_package "$to_rebuild"
                tui_msg "Rebuild" "$to_rebuild rebuilt."
                ;;
            "Create new recipe")
                local name=$(tui_input "New Recipe" "Package name:") || continue
                [[ -z "$name" ]] && continue
                new_recipe "$name"
                ;;
            "Edit recipe")
                local avail2=$(list_recipes 2>/dev/null | awk '{print $1}')
                if [[ -z "$avail2" ]]; then
                    tui_msg "No recipes" "No recipes found."
                    continue
                fi
                local to_edit=$(tui_menu "Select recipe" "" $avail2) || continue
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
                local to_fetch=$(tui_menu "Select recipe" "" ${remote_recipes}) || continue
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
                local avail3=$(list_recipes 2>/dev/null | awk '{print $1}')
                if [[ -z "$avail3" ]]; then
                    tui_msg "No recipes" "No recipes found."
                    continue
                fi
                local to_lint=$(tui_menu "Select recipe" "" $avail3) || continue
                local lint_result=$(lint_recipe "$to_lint" 2>&1)
                tui_msg "Lint Result: $to_lint" "$lint_result"
                ;;
            "Checksum recipe")
                local avail4=$(list_recipes 2>/dev/null | awk '{print $1}')
                if [[ -z "$avail4" ]]; then
                    tui_msg "No recipes" "No recipes found."
                    continue
                fi
                local to_checksum=$(tui_menu "Select recipe" "" $avail4) || continue
                local checksum_result=$(checksum_recipe "$to_checksum" 2>&1)
                tui_msg "Checksums: $to_checksum" "${checksum_result}"
                ;;
            "Sync recipes")
                sync_recipes
                tui_msg "Sync" "Recipes synchronized."
                ;;
            "Recovery – check & repair source packages")
                source "${POWERUSER_DIR}/lib/gartix_recovery.bash" 2>/dev/null || {
                    tui_msg "Error" "Recovery module not available."
                    continue
                }
                gartix_recovery_status
                if tui_yesno "Repair source packages?" "Attempt to repair all source‑built packages?"; then
                    local repaired=()
                    while IFS='|' read -r pkgname _; do
                        [[ -n "${pkgname}" ]] || continue
                        gartix_recovery_repair "${pkgname}" && repaired+=("${pkgname}")
                    done < <(tail -n +2 "${POWERUSER_DIR}/db/local.db" 2>/dev/null)
                    if [[ ${#repaired[@]} -gt 0 ]]; then
                        tui_msg "Recovery Complete" "Repaired: ${repaired[*]}"
                    else
                        tui_msg "Recovery" "No packages were repaired."
                    fi
                fi
                ;;
            "Upgrade recipes")
                upgrade_gartix
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