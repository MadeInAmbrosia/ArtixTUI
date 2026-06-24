#!/usr/bin/env bash
set -Eeuo pipefail

ATA_MAP_CACHE="/tmp/ata-pkg-map.txt"

ata_build_package_map() {
    log_info "Building package availability map..."
    pacman -Sy --noconfirm 2>/dev/null || true
    : > "${ATA_MAP_CACHE}"

    # Systemd internal units that don't need migration
    local -A skip_units=(
        ["getty@.service"]=1
        ["serial-getty@.service"]=1
        ["systemd-journald.service"]=1
        ["systemd-logind.service"]=1
        ["systemd-resolved.service"]=1
        ["systemd-timesyncd.service"]=1
        ["systemd-networkd.service"]=1
        ["systemd-udevd.service"]=1
        ["systemd-tmpfiles-setup.service"]=1
        ["systemd-sysusers.service"]=1
        ["systemd-random-seed.service"]=1
        ["systemd-update-utmp.service"]=1
        ["systemd-backlight@.service"]=1
        ["systemd-fsck@.service"]=1
        ["systemd-user-sessions.service"]=1
        ["user-runtime-dir@.service"]=1
        ["systemd-rfkill.service"]=1
        ["systemd-journal-flush.service"]=1
    )

    while IFS= read -r unit; do
        [[ -n "${skip_units[${unit}]:-}" ]] && continue

        local pkg=""
        unit="${unit%.service}"
        unit="${unit%.target}"
        unit="${unit%.timer}"
        unit="${unit%.socket}"
        unit="${unit%@*}"

        local svc_file=""
        for path in /usr/lib/systemd/system /etc/systemd/system; do
            for ext in service target timer socket; do
                if [[ -f "${path}/${unit}.${ext}" ]]; then
                    svc_file="${path}/${unit}.${ext}"
                    break 2
                fi
            done
        done
        if [[ -n "${svc_file}" ]]; then
            pkg=$(pacman -Qo "${svc_file}" 2>/dev/null | awk '{print $5}' | cut -d/ -f1) || true
        fi
        [[ -z "${pkg}" ]] && pkg="${unit}"

        local arch_repo=""
        arch_repo=$(pacman -Si "${pkg}" 2>/dev/null | grep 'Repository' | awk '{print $3}') || true
        [[ -z "${arch_repo}" ]] && arch_repo="unknown"

        local artix_repo=""
        case "${arch_repo}" in
            core) artix_repo="system" ;;
            extra) artix_repo="world" ;;
            multilib) artix_repo="lib32" ;;
            *) artix_repo="${arch_repo}" ;;
        esac

        local artix_pkg="${pkg}"
        local artix_ver=""
        if ! pacman -Si "${artix_pkg}" 2>/dev/null | grep -q 'Repository'; then
            local found=0
            for suffix in -openrc -runit -dinit -s6; do
                if pacman -Si "${pkg}${suffix}" 2>/dev/null | grep -q 'Repository'; then
                    artix_pkg="${pkg}${suffix}"
                    found=1
                    break
                fi
            done
            [[ $found -eq 0 ]] && artix_pkg="MISSING"
        fi

        if [[ "${artix_pkg}" != "MISSING" ]]; then
            artix_ver=$(pacman -Si "${artix_pkg}" 2>/dev/null | grep 'Version' | awk '{print $3}')
        fi

        local arch_ver=""
        arch_ver=$(pacman -Q "${pkg}" 2>/dev/null | awk '{print $2}') || true

        local status="migratable"
        [[ "${artix_pkg}" == "MISSING" ]] && status="no-artix-equivalent"
        [[ -n "${arch_ver}" && -n "${artix_ver}" && "${arch_ver}" != "${artix_ver}" ]] && status="version-mismatch"

        printf '%s|%s|%s|%s|%s|%s\n' \
            "${unit}" "${pkg}" "${arch_ver}" "${artix_pkg}" "${artix_ver}" "${status}" >> "${ATA_MAP_CACHE}"
    done < /tmp/ata-units.txt
}

ata_show_migration_list() {
    tui_msg "Package Migration" "The following systemd units were detected."

    local items=()
    while IFS='|' read -r unit pkg arch_ver artix_pkg artix_ver status; do
        local label="${unit} → ${artix_pkg}"
        case "${status}" in
            version-mismatch) label+=" [ARCH: ${arch_ver} / ARTIX: ${artix_ver}]" ;;
            no-artix-equivalent) label+=" [NO ARTIX EQUIVALENT]" ;;
        esac
        items+=("${label}")
    done < "${ATA_MAP_CACHE}"

    [[ ${#items[@]} -eq 0 ]] && { tui_msg "No units" "No enabled systemd units found."; return; }

    local chosen
    chosen=$(tui_checklist "Migrate Services" "Select services to migrate:" "${items[@]}") || true
    printf '%s\n' "${chosen}" | sed 's/ .*//' > /tmp/ata-migrate-selection.txt
}