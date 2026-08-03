#!/usr/bin/env bash
set -Eeuo pipefail

_filly_send() {
    local _dir _tmp _out
    _dir=$(mktemp -d --tmpdir anvil-tui-XXXXXX)
    chmod 700 "$_dir"
    _tmp="$_dir/input.json"
    _out="$_dir/output.json"
    printf '%s\n' "$1" > "$_tmp"
    "${FILLY_BIN}" oneshot --input "$_tmp" 2>/dev/null | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' > "$_out" || true
    cat "$_out" 2>/dev/null
    rm -rf "$_dir"
}

_filly_result() {
    local _json
    _json=$(_filly_send "$1")
    [[ -z "$_json" ]] && return 1
    [[ "$(jq -r '.cancelled' <<< "$_json")" == "true" ]] && return 1
    jq -r '.result // empty' <<< "$_json" 2>/dev/null
}

tui_anvil_hub() {
    local categories_json
    categories_json='[
        {"category":"Packages","actions":[
            {"key":"list_installed","description":"List installed packages"},
            {"key":"list_recipes","description":"List available recipes"},
            {"key":"package_info","description":"View build details for a package"},
            {"key":"rebuild","description":"Rebuild a package"},
            {"key":"fetch_recipe","description":"Download a community recipe"},
            {"key":"fetch_all","description":"Download all recipe sources"}
        ]},
        {"category":"Recipes","actions":[
            {"key":"create_recipe","description":"Start a new recipe from template"},
            {"key":"edit_recipe","description":"Modify an existing recipe"},
            {"key":"lint_recipe","description":"Validate recipe syntax"},
            {"key":"checksum_recipe","description":"Generate SHA256 hashes"}
        ]},
        {"category":"Kernel","actions":[
            {"key":"edit_config","description":"Modify the running kernel .config"},
            {"key":"menuconfig","description":"Launch make menuconfig"},
            {"key":"fetch_source","description":"Download kernel source for compilation"}
        ]},
        {"category":"Maintenance","actions":[
            {"key":"sync_recipes","description":"Update .LIST and recipes from community repo"},
            {"key":"manage_sections","description":"Enable/disable recipe sources"},
            {"key":"upgrade","description":"Backup and update from remote"},
            {"key":"cache_clean","description":"Remove obsolete cached packages"},
            {"key":"recovery","description":"Check and repair source packages"}
        ]}
    ]'

    local result
    result=$(_filly_result '{"widget":"anvil","params":{"title":"anvil","categories":'"${categories_json}"'}}')

    echo "${result}"
}

tui_main() {
    while true; do
        local action
        action=$(tui_anvil_hub) || break

        case "$action" in
            "list_installed")
                local installed
                installed=$(list_packages 2>/dev/null)
                _filly_send '{"widget":"msg","params":{"title":"Installed Packages","message":"'"${installed:-No packages installed.}"'"}}' >/dev/null
                ;;
            "list_recipes")
                local recipes
                recipes=$(list_recipes 2>/dev/null)
                _filly_send '{"widget":"msg","params":{"title":"Available Recipes","message":"'"${recipes:-No recipes found.}"'"}}' >/dev/null
                ;;
            "package_info")
                local pkg_list
                pkg_list=$(list_packages 2>/dev/null | awk '{print $1}')
                if [[ -z "$pkg_list" ]]; then
                    _filly_send '{"widget":"msg","params":{"title":"No packages","message":"No source packages installed yet."}}' >/dev/null
                    continue
                fi
                local pkg
                pkg=$(_filly_result '{"widget":"menu","params":{"title":"Select Package","choices":'"$(printf '%s\n' $pkg_list | jq -R . | jq -s .)"'}}') || continue
                local info
                info=$(info_package "$pkg")
                _filly_send '{"widget":"msg","params":{"title":"Package Info: '"${pkg}"'","message":"'"${info}"'"}}' >/dev/null
                ;;
            "rebuild")
                local avail
                avail=$(list_recipes 2>/dev/null | awk '{print $1}')
                if [[ -z "$avail" ]]; then
                    _filly_send '{"widget":"msg","params":{"title":"No recipes","message":"No recipes found."}}' >/dev/null
                    continue
                fi
                local to_rebuild
                to_rebuild=$(_filly_result '{"widget":"menu","params":{"title":"Select package","choices":'"$(printf '%s\n' $avail | jq -R . | jq -s .)"'}}') || continue
                rebuild_package "$to_rebuild"
                _filly_send '{"widget":"msg","params":{"title":"Rebuild","message":"'"${to_rebuild}"' rebuilt."}}' >/dev/null
                ;;
            "create_recipe")
                local name
                name=$(_filly_result '{"widget":"input","params":{"title":"New Recipe","message":"Package name:"}}') || continue
                [[ -z "$name" ]] && continue
                new_recipe "$name"
                ;;
            "edit_recipe")
                local avail2
                avail2=$(list_recipes 2>/dev/null | awk '{print $1}')
                if [[ -z "$avail2" ]]; then
                    _filly_send '{"widget":"msg","params":{"title":"No recipes","message":"No recipes found."}}' >/dev/null
                    continue
                fi
                local to_edit
                to_edit=$(_filly_result '{"widget":"menu","params":{"title":"Select recipe","choices":'"$(printf '%s\n' $avail2 | jq -R . | jq -s .)"'}}') || continue
                edit_recipe "$to_edit"
                ;;
            "edit_config") edit_config ;;
            "menuconfig") launch_menuconfig ;;
            "fetch_source") fetch_source linux ;;
            "fetch_recipe")
                local remote_recipes
                remote_recipes=$(list_available 2>/dev/null | awk '{print $1}')
                if [[ -z "$remote_recipes" ]]; then
                    _filly_send '{"widget":"msg","params":{"title":"No recipes","message":"No recipes available from the community repo."}}' >/dev/null
                    continue
                fi
                local to_fetch
                to_fetch=$(_filly_result '{"widget":"menu","params":{"title":"Select recipe","choices":'"$(printf '%s\n' ${remote_recipes} | jq -R . | jq -s .)"'}}') || continue
                fetch_recipe "$to_fetch"
                _filly_send '{"widget":"msg","params":{"title":"Fetch Recipe","message":"'"${to_fetch}"' downloaded."}}' >/dev/null
                ;;
            "fetch_all") fetch_all_sources ;;
            "manage_sections") tui_manage_sections ;;
            "lint_recipe")
                local avail3
                avail3=$(list_recipes 2>/dev/null | awk '{print $1}')
                if [[ -z "$avail3" ]]; then
                    _filly_send '{"widget":"msg","params":{"title":"No recipes","message":"No recipes found."}}' >/dev/null
                    continue
                fi
                local to_lint
                to_lint=$(_filly_result '{"widget":"menu","params":{"title":"Select recipe","choices":'"$(printf '%s\n' $avail3 | jq -R . | jq -s .)"'}}') || continue
                local lint_result
                lint_result=$(lint_recipe "$to_lint" 2>&1)
                _filly_send '{"widget":"msg","params":{"title":"Lint Result: '"${to_lint}"'","message":"'"${lint_result}"'"}}' >/dev/null
                ;;
            "checksum_recipe")
                local avail4
                avail4=$(list_recipes 2>/dev/null | awk '{print $1}')
                if [[ -z "$avail4" ]]; then
                    _filly_send '{"widget":"msg","params":{"title":"No recipes","message":"No recipes found."}}' >/dev/null
                    continue
                fi
                local to_checksum
                to_checksum=$(_filly_result '{"widget":"menu","params":{"title":"Select recipe","choices":'"$(printf '%s\n' $avail4 | jq -R . | jq -s .)"'}}') || continue
                local checksum_result
                checksum_result=$(checksum_recipe "$to_checksum" 2>&1)
                _filly_send '{"widget":"msg","params":{"title":"Checksums: '"${to_checksum}"'","message":"'"${checksum_result}"'"}}' >/dev/null
                ;;
            "sync_recipes") sync_recipes ;;
            "upgrade") upgrade_anvil ;;
            "cache_clean") cache_clean ;;
            "recovery")
                anvil_recovery_status
                if _filly_result '{"widget":"yesno","params":{"title":"Repair?","message":"Repair detected issues?"}}' | grep -q 'true'; then
                    local repaired=()
                    while IFS='|' read -r pkgname _; do
                        [[ -n "${pkgname}" ]] || continue
                        anvil_recovery_repair "${pkgname}" && repaired+=("${pkgname}")
                    done < <(tail -n +2 "${POWERUSER_DIR}/db/local.db" 2>/dev/null)
                    if [[ ${#repaired[@]} -gt 0 ]]; then
                        _filly_send '{"widget":"msg","params":{"title":"Recovery Complete","message":"Repaired: '"${repaired[*]}"'"}}' >/dev/null
                    else
                        _filly_send '{"widget":"msg","params":{"title":"Recovery","message":"No packages were repaired."}}' >/dev/null
                    fi
                fi
                ;;
            *) break ;;
        esac
    done
    clear
}