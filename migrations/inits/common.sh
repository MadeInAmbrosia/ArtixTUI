#!/usr/bin/env bash
set -Eeuo pipefail

HUB_INIT="openrc"

declare -A OPENRC_TO_DINIT=(
    ["NetworkManager"]="NetworkManager"
    ["networkmanager"]="NetworkManager"
    ["dhcpcd"]="dhcpcd"
    ["iwd"]="iwd"
    ["sshd"]="sshd"
    ["cronie"]="cronie"
    ["dbus"]="dbus"
    ["elogind"]="elogind"
    ["seatd"]="seatd"
    ["acpid"]="acpid"
    ["alsa"]="alsa"
    ["bluetoothd"]="bluetoothd"
    ["connmand"]="connmand"
    ["ufw"]="ufw"
    ["firewalld"]="firewalld"
    ["ntpd"]="ntpd"
    ["syslog-ng"]="syslog-ng"
    ["lvm2-lvmetad"]="lvm2"
    ["dmcrypt"]="dmcrypt"
    ["zfs-zed"]="zfs-zed"
)

declare -A OPENRC_TO_RUNIT=(
    ["NetworkManager"]="NetworkManager"
    ["networkmanager"]="NetworkManager"
    ["dhcpcd"]="dhcpcd"
    ["iwd"]="iwd"
    ["sshd"]="sshd"
    ["cronie"]="cronie"
    ["dbus"]="dbus"
    ["elogind"]="elogind"
    ["seatd"]="seatd"
    ["acpid"]="acpid"
    ["alsa"]="alsa"
    ["bluetoothd"]="bluetoothd"
    ["connmand"]="connmand"
    ["ufw"]="ufw"
    ["firewalld"]="firewalld"
    ["ntpd"]="ntpd"
    ["syslog-ng"]="syslog-ng"
)

declare -A OPENRC_TO_S6=(
    ["NetworkManager"]="NetworkManager"
    ["networkmanager"]="NetworkManager"
    ["dhcpcd"]="dhcpcd"
    ["iwd"]="iwd"
    ["sshd"]="sshd"
    ["cronie"]="cronie"
    ["dbus"]="dbus"
    ["elogind"]="elogind"
    ["seatd"]="seatd"
    ["acpid"]="acpid"
    ["alsa"]="alsa"
    ["bluetoothd"]="bluetoothd"
    ["connmand"]="connmand"
    ["ufw"]="ufw"
    ["firewalld"]="firewalld"
    ["ntpd"]="ntpd"
    ["syslog-ng"]="syslog-ng"
)

declare -A DINIT_TO_OPENRC=()
for key in "${!OPENRC_TO_DINIT[@]}"; do
    DINIT_TO_OPENRC["${OPENRC_TO_DINIT[$key]}"]="$key"
done

declare -A RUNIT_TO_OPENRC=()
for key in "${!OPENRC_TO_RUNIT[@]}"; do
    RUNIT_TO_OPENRC["${OPENRC_TO_RUNIT[$key]}"]="$key"
done

declare -A S6_TO_OPENRC=()
for key in "${!OPENRC_TO_S6[@]}"; do
    S6_TO_OPENRC["${OPENRC_TO_S6[$key]}"]="$key"
done

declare -A SYSTEMD_TO_OPENRC=(
    ["NetworkManager.service"]="NetworkManager"
    ["networkmanager.service"]="NetworkManager"
    ["dhcpcd.service"]="dhcpcd"
    ["iwd.service"]="iwd"
    ["sshd.service"]="sshd"
    ["cronie.service"]="cronie"
    ["dbus.service"]="dbus"
    ["elogind.service"]="elogind"
    ["seatd.service"]="seatd"
    ["acpid.service"]="acpid"
    ["alsa-restore.service"]="alsa"
    ["bluetooth.service"]="bluetoothd"
    ["connman.service"]="connmand"
    ["ufw.service"]="ufw"
    ["firewalld.service"]="firewalld"
    ["ntpd.service"]="ntpd"
    ["syslog-ng.service"]="syslog-ng"
)

get_migration_table() {
    local src="${1}" tgt="${2}"
    local table_name="${src^^}_TO_${tgt^^}"
    declare -p "$table_name" &>/dev/null && echo "$table_name" || echo ""
}

list_enabled_services() {
    local init="${1:-openrc}"
    case "$init" in
        openrc) rc-update show -v 2>/dev/null | awk '/default|boot|nonetwork/ {print $1}' | sort -u ;;
        runit)  [[ -d /etc/runit/runsvdir/default ]] && ls /etc/runit/runsvdir/default/ 2>/dev/null ;;
        dinit)  [[ -d /etc/dinit.d/boot.d ]] && ls /etc/dinit.d/boot.d/ 2>/dev/null | sed 's/\.d$//' ;;
        s6)     s6-rc-db list services 2>/dev/null || true ;;
        systemd) systemctl list-unit-files --state=enabled 2>/dev/null | awk '/\.service/ {print $1}' ;;
        *)      return 1 ;;
    esac
}

map_service() {
    local src="${1}" tgt="${2}" svc="${3}"
    local table_name
    table_name=$(get_migration_table "$src" "$tgt")
    if [[ -n "$table_name" ]]; then
        local mapped
        mapped=$(eval "echo \${$table_name[$svc]:-}")
        [[ -n "$mapped" ]] && echo "$mapped" && return 0
    fi
    return 1
}

install_target_init() {
    local init="${1}"
    local pkgs=()
    case "$init" in
        openrc) pkgs=(openrc) ;;
        runit)  pkgs=(runit) ;;
        dinit)  pkgs=(dinit dinit-base dinit-rc) ;;
        s6)     pkgs=(s6 s6-rc) ;;
        *) die "Unknown init system: $init" ;;
    esac
    log_info "Installing target init packages: ${pkgs[*]}"
    pacman -S --noconfirm --needed "${pkgs[@]}" || die "Failed to install ${init}"
}

backup_init_config() {
    local init="${1}" backup_dir="${2}"
    mkdir -p "$backup_dir"
    case "$init" in
        openrc) cp -a /etc/runlevels "$backup_dir/" 2>/dev/null || true ;;
        runit)  cp -a /etc/runit/runsvdir "$backup_dir/" 2>/dev/null || true ;;
        dinit)  cp -a /etc/dinit.d "$backup_dir/" 2>/dev/null || true ;;
        s6)     cp -a /etc/s6 "$backup_dir/" 2>/dev/null || true ;;
        systemd) cp -a /etc/systemd "$backup_dir/" 2>/dev/null || true ;;
    esac
    log_info "Init configuration backed up to $backup_dir"
}

detect_custom_services() {
    local init="${1}"
    local -a custom=()
    local svc
    while IFS= read -r svc; do
        [[ -z "$svc" ]] && continue
        local owned=0
        case "$init" in
            openrc) pacman -Qo "/etc/init.d/$svc" &>/dev/null && owned=1 ;;
            runit)  pacman -Qo "/etc/runit/sv/$svc" &>/dev/null && owned=1 ;;
            dinit)  pacman -Qo "/etc/dinit.d/$svc" &>/dev/null && owned=1 ;;
            s6)     pacman -Qo "/etc/s6/sv/$svc" &>/dev/null && owned=1 ;;
        esac
        [[ $owned -eq 0 ]] && custom+=("$svc")
    done < <(list_enabled_services "$init")
    printf '%s\n' "${custom[@]}"
}

validate_migration() {
    local src="${1}" tgt="${2}"
    [[ "$src" != "$tgt" ]] || die "Source and target init are the same: $src"
    command -v pacman &>/dev/null || die "This migration requires pacman"
}

has_direct_table() {
    local src="${1}" tgt="${2}"
    local table_name="${src^^}_TO_${tgt^^}"
    declare -p "$table_name" &>/dev/null && return 0 || return 1
}

_run_single_migration() {
    local source_init="${1}" target_init="${2}"
    log_info "Migrating services from $source_init to $target_init..."
    local enabled_svcs
    enabled_svcs=$(list_enabled_services "$source_init")
    local migrated=0 skipped=0
    while IFS= read -r svc; do
        [[ -z "$svc" ]] && continue
        local mapped
        mapped=$(map_service "$source_init" "$target_init" "$svc" 2>/dev/null || true)
        if [[ -n "$mapped" ]]; then
            log_info "  Migrating: $svc → $mapped"
            enable_service "$mapped" 2>/dev/null || { log_warn "  Failed to enable $mapped"; ((skipped++)); continue; }
            ((migrated++))
        else
            log_warn "  No mapping for $svc – skipping"
            ((skipped++))
        fi
    done <<< "$enabled_svcs"
    log_info "Step complete: $migrated services migrated, $skipped skipped"
}

run_init_migration() {
    local source_init="${1}" target_init="${2}"
    validate_migration "$source_init" "$target_init"

    local backup_dir="/root/init-backup-${source_init}-$(date +%Y%m%d-%H%M%S)"
    log_info "Backing up current init configuration..."
    backup_init_config "$source_init" "$backup_dir"

    log_info "Detecting custom services..."
    local -a custom_services
    mapfile -t custom_services < <(detect_custom_services "$source_init")
    if [[ ${#custom_services[@]} -gt 0 ]]; then
        log_warn "Custom services detected (not owned by packages): ${custom_services[*]}"
        mkdir -p "$backup_dir/custom"
        for svc in "${custom_services[@]}"; do
            case "$source_init" in
                openrc) cp -a "/etc/init.d/$svc" "$backup_dir/custom/" 2>/dev/null || true ;;
                runit)  cp -a "/etc/runit/sv/$svc" "$backup_dir/custom/" 2>/dev/null || true ;;
                dinit)  cp -a "/etc/dinit.d/$svc" "$backup_dir/custom/" 2>/dev/null || true ;;
                s6)     cp -a "/etc/s6/sv/$svc" "$backup_dir/custom/" 2>/dev/null || true ;;
            esac
        done
        log_info "Custom services saved to $backup_dir/custom/"
    fi

    log_info "Installing target init system: $target_init"
    install_target_init "$target_init"

    if has_direct_table "$source_init" "$target_init"; then
        log_info "Direct migration: $source_init → $target_init"
        _run_single_migration "$source_init" "$target_init"
    elif [[ "$source_init" != "$HUB_INIT" && "$target_init" != "$HUB_INIT" ]]; then
        log_info "No direct table – chaining through $HUB_INIT"
        log_info "Step 1/2: $source_init → $HUB_INIT"
        _run_single_migration "$source_init" "$HUB_INIT"
        log_info "Step 2/2: $HUB_INIT → $target_init"
        _run_single_migration "$HUB_INIT" "$target_init"
    elif [[ "$source_init" != "$HUB_INIT" && "$target_init" == "$HUB_INIT" ]]; then
        log_info "Migration: $source_init → $HUB_INIT"
        _run_single_migration "$source_init" "$HUB_INIT"
    elif [[ "$source_init" == "$HUB_INIT" && "$target_init" != "$HUB_INIT" ]]; then
        log_info "Migration: $HUB_INIT → $target_init"
        _run_single_migration "$HUB_INIT" "$target_init"
    fi

    if [[ ${#custom_services[@]} -gt 0 ]]; then
        log_warn "Custom services were not automatically migrated."
        log_warn "Review $backup_dir/custom/ and recreate them for $target_init manually."
    fi

    log_info "Migration complete. Please reboot."
}

tui_init_migration_menu() {
    local source_init target_init
    source_init=$(tui_menu "Source Init" "Select current init system:" \
        "openrc" "runit" "dinit" "s6" "systemd") || return 1
    target_init=$(tui_menu "Target Init" "Select new init system:" \
        "openrc" "runit" "dinit" "s6") || return 1
    [[ "$source_init" != "$target_init" ]] || die "Source and target are the same."

    local script="${MIGRATIONS_DIR}/inits/${source_init}-to-${target_init}.sh"
    if [[ -f "$script" ]]; then
        source "$script"
    else
        log_info "No direct script for $source_init → $target_init – chaining through $HUB_INIT"
        local step1="${MIGRATIONS_DIR}/inits/${source_init}-to-${HUB_INIT}.sh"
        local step2="${MIGRATIONS_DIR}/inits/${HUB_INIT}-to-${target_init}.sh"
        [[ -f "$step1" ]] && { log_info "Running: $source_init → $HUB_INIT"; source "$step1"; }
        [[ -f "$step2" ]] && { log_info "Running: $HUB_INIT → $target_init"; source "$step2"; }
    fi
    log_info "Init migration complete. Please reboot."
}