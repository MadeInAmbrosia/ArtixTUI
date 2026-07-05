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

tui_anvil_hub() {
    local actions_json
    actions_json='[
        {"category":"Packages","actions":[
            {"key":"list_installed","label":"List installed packages","description":"Show source-built packages"},
            {"key":"list_recipes","label":"List available recipes","description":"Browse all recipe files"},
            {"key":"package_info","label":"Package info","description":"View build details for a package"},
            {"key":"rebuild","label":"Rebuild a package","description":"Recompile a source package"},
            {"key":"fetch_recipe","label":"Fetch recipe from repo","description":"Download a community recipe"},
            {"key":"fetch_all","label":"Fetch all sources","description":"Download all recipe sources"}
        ]},
        {"category":"Recipes","actions":[
            {"key":"create_recipe","label":"Create new recipe","description":"Start a new recipe from template"},
            {"key":"edit_recipe","label":"Edit recipe","description":"Modify an existing recipe"},
            {"key":"lint_recipe","label":"Lint recipe","description":"Validate recipe syntax"},
            {"key":"checksum_recipe","label":"Checksum recipe","description":"Generate SHA256 hashes"}
        ]},
        {"category":"Kernel","actions":[
            {"key":"edit_config","label":"Edit kernel config","description":"Modify the running kernel .config"},
            {"key":"menuconfig","label":"Menuconfig","description":"Launch make menuconfig"},
            {"key":"fetch_source","label":"Fetch kernel source","description":"Download kernel source for compilation"}
        ]},
        {"category":"Maintenance","actions":[
            {"key":"sync_recipes","label":"Sync recipes","description":"Update .LIST and recipes from community repo"},
            {"key":"manage_sections","label":"Manage recipe sections","description":"Enable/disable recipe sources"},
            {"key":"upgrade","label":"Upgrade recipes","description":"Backup and update from remote"},
            {"key":"cache_clean","label":"Clean cache","description":"Remove obsolete cached packages"},
            {"key":"recovery","label":"Recovery","description":"Check and repair source packages"}
        ]}
    ]'

    local result
    result=$(_forge_result '{"widget":"anvil","title":"anvil","actions":'"${actions_json}"'}')

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
                _forge '{"widget":"msg","title":"Installed Packages","message":"'"${installed:-No packages installed.}"'"}' >/dev/null
                ;;
            "list_recipes")
                local recipes
                recipes=$(list_recipes 2>/dev/null)
                _forge '{"widget":"msg","title":"Available Recipes","message":"'"${recipes:-No recipes found.}"'"}' >/dev/null
                ;;
            "package_info")
                local pkg_list
                pkg_list=$(list_packages 2>/dev/null | awk '{print $1}')
                if [[ -z "$pkg_list" ]]; then
                    _forge '{"widget":"msg","title":"No packages","message":"No source packages installed yet."}' >/dev/null
                    continue
                fi
                local pkg
                pkg=$(_forge_result '{"widget":"menu","title":"Select Package","choices":'"$(printf '%s\n' $pkg_list | jq -R . | jq -s .)"'}') || continue
                local info
                info=$(info_package "$pkg")
                _forge '{"widget":"msg","title":"Package Info: '"${pkg}"'","message":"'"${info}"'"}' >/dev/null
                ;;
            "rebuild")
                local avail
                avail=$(list_recipes 2>/dev/null | awk '{print $1}')
                if [[ -z "$avail" ]]; then
                    _forge '{"widget":"msg","title":"No recipes","message":"No recipes found."}' >/dev/null
                    continue
                fi
                local to_rebuild
                to_rebuild=$(_forge_result '{"widget":"menu","title":"Select package","choices":'"$(printf '%s\n' $avail | jq -R . | jq -s .)"'}') || continue
                rebuild_package "$to_rebuild"
                _forge '{"widget":"msg","title":"Rebuild","message":"'"${to_rebuild}"' rebuilt."}' >/dev/null
                ;;
            "create_recipe")
                local name
                name=$(_forge_result '{"widget":"input","title":"New Recipe","message":"Package name:"}') || continue
                [[ -z "$name" ]] && continue
                new_recipe "$name"
                ;;
            "edit_recipe")
                local avail2
                avail2=$(list_recipes 2>/dev/null | awk '{print $1}')
                if [[ -z "$avail2" ]]; then
                    _forge '{"widget":"msg","title":"No recipes","message":"No recipes found."}' >/dev/null
                    continue
                fi
                local to_edit
                to_edit=$(_forge_result '{"widget":"menu","title":"Select recipe","choices":'"$(printf '%s\n' $avail2 | jq -R . | jq -s .)"'}') || continue
                edit_recipe "$to_edit"
                ;;
            "edit_config") edit_config ;;
            "menuconfig") launch_menuconfig ;;
            "fetch_source") fetch_source linux ;;
            "fetch_recipe")
                local remote_recipes
                remote_recipes=$(list_available 2>/dev/null | awk '{print $1}')
                if [[ -z "$remote_recipes" ]]; then
                    _forge '{"widget":"msg","title":"No recipes","message":"No recipes available from the community repo."}' >/dev/null
                    continue
                fi
                local to_fetch
                to_fetch=$(_forge_result '{"widget":"menu","title":"Select recipe","choices":'"$(printf '%s\n' ${remote_recipes} | jq -R . | jq -s .)"'}') || continue
                fetch_recipe "$to_fetch"
                _forge '{"widget":"msg","title":"Fetch Recipe","message":"'"${to_fetch}"' downloaded."}' >/dev/null
                ;;
            "fetch_all") fetch_all_sources ;;
            "manage_sections") tui_manage_sections ;;
            "lint_recipe")
                local avail3
                avail3=$(list_recipes 2>/dev/null | awk '{print $1}')
                if [[ -z "$avail3" ]]; then
                    _forge '{"widget":"msg","title":"No recipes","message":"No recipes found."}' >/dev/null
                    continue
                fi
                local to_lint
                to_lint=$(_forge_result '{"widget":"menu","title":"Select recipe","choices":'"$(printf '%s\n' $avail3 | jq -R . | jq -s .)"'}') || continue
                local lint_result
                lint_result=$(lint_recipe "$to_lint" 2>&1)
                _forge '{"widget":"msg","title":"Lint Result: '"${to_lint}"'","message":"'"${lint_result}"'"}' >/dev/null
                ;;
            "checksum_recipe")
                local avail4
                avail4=$(list_recipes 2>/dev/null | awk '{print $1}')
                if [[ -z "$avail4" ]]; then
                    _forge '{"widget":"msg","title":"No recipes","message":"No recipes found."}' >/dev/null
                    continue
                fi
                local to_checksum
                to_checksum=$(_forge_result '{"widget":"menu","title":"Select recipe","choices":'"$(printf '%s\n' $avail4 | jq -R . | jq -s .)"'}') || continue
                local checksum_result
                checksum_result=$(checksum_recipe "$to_checksum" 2>&1)
                _forge '{"widget":"msg","title":"Checksums: '"${to_checksum}"'","message":"'"${checksum_result}"'"}' >/dev/null
                ;;
            "sync_recipes") sync_recipes ;;
            "upgrade") upgrade_anvil ;;
            "cache_clean") cache_clean ;;
            "recovery")
                anvil_recovery_status
                if _forge_result '{"widget":"yesno","title":"Repair?","message":"Repair detected issues?"}' | grep -q 'true'; then
                    local repaired=()
                    while IFS='|' read -r pkgname _; do
                        [[ -n "${pkgname}" ]] || continue
                        anvil_recovery_repair "${pkgname}" && repaired+=("${pkgname}")
                    done < <(tail -n +2 "${POWERUSER_DIR}/db/local.db" 2>/dev/null)
                    if [[ ${#repaired[@]} -gt 0 ]]; then
                        _forge '{"widget":"msg","title":"Recovery Complete","message":"Repaired: '"${repaired[*]}"'"}' >/dev/null
                    else
                        _forge '{"widget":"msg","title":"Recovery","message":"No packages were repaired."}' >/dev/null
                    fi
                fi
                ;;
            *) break ;;
        esac
    done
    clear
}